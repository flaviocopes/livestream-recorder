import Combine
import Foundation

private final class SendableProcess: @unchecked Sendable {
    let value: Process

    init(_ value: Process) {
        self.value = value
    }
}

private struct RecordingRequest {
    let streamURL: URL
    let mode: RecordingMode
    let cookieBrowser: CookieBrowser
    let destination: URL
    let toolchain: RecordingToolchain
}

@MainActor
final class RecordingController: ObservableObject {
    @Published private(set) var state: RecordingState = .idle
    @Published private(set) var progressText: String?
    @Published private(set) var recentMessages: [String] = []
    @Published private(set) var capturedMediaDuration: TimeInterval = 0
    @Published private(set) var catchUpPhase: CatchUpPhase?

    private var runningProcess: SendableProcess?
    private var standardOutputPipe: Pipe?
    private var standardErrorPipe: Pipe?
    private var outputBuffer = ""
    private var errorBuffer = ""
    private var destination: URL?
    private var recordingStartedAt: Date?
    private var livestreamStartedAt: Date?
    private var reportedFileURL: URL?
    private var lastErrorMessage: String?
    private var stopWasRequested = false
    private var downloadHasStarted = false
    private var sessionID: UUID?
    private var terminationCompletion: (() -> Void)?
    private var currentRequest: RecordingRequest?
    private var retryTask: Task<Void, Never>?
    private var retryAttempt = 0
    private var finalizationTask: Task<Void, Never>?
    private var timelineTask: Task<Void, Never>?

    func start(
        streamURL: URL,
        mode: RecordingMode,
        cookieBrowser: CookieBrowser,
        destination: URL,
        toolchain: RecordingToolchain
    ) {
        guard !state.isActive else { return }

        let request = RecordingRequest(
            streamURL: streamURL,
            mode: mode,
            cookieBrowser: cookieBrowser,
            destination: destination,
            toolchain: toolchain
        )
        currentRequest = request
        retryAttempt = 0
        progressText = nil
        recentMessages = []
        capturedMediaDuration = 0
        catchUpPhase = mode == .fromBeginning ? .catchingUp : nil
        launch(request)
    }

    private func launch(_ request: RecordingRequest) {
        state = .preparing
        progressText = nil
        reportedFileURL = nil
        lastErrorMessage = nil
        stopWasRequested = false
        downloadHasStarted = false
        livestreamStartedAt = nil
        destination = request.destination

        do {
            try FileManager.default.createDirectory(
                at: request.destination,
                withIntermediateDirectories: true
            )

            guard FileManager.default.isWritableFile(atPath: request.destination.path) else {
                throw CocoaError(.fileWriteNoPermission)
            }

            let startedAt = Date.now
            let command = YTDLPCommandBuilder.build(
                streamURL: request.streamURL,
                mode: request.mode,
                cookieBrowser: request.cookieBrowser,
                destination: request.destination,
                toolchain: request.toolchain,
                date: startedAt
            )
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            let newSessionID = UUID()

            process.executableURL = command.executableURL
            process.arguments = command.arguments
            process.environment = command.environment
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            process.qualityOfService = .userInitiated

            outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor [weak self] in
                    self?.consume(text, fromStandardError: false, sessionID: newSessionID)
                }
            }

            errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor [weak self] in
                    self?.consume(text, fromStandardError: true, sessionID: newSessionID)
                }
            }

            process.terminationHandler = { [weak self] finishedProcess in
                let status = finishedProcess.terminationStatus
                Task { @MainActor [weak self] in
                    self?.processDidTerminate(status: status, sessionID: newSessionID)
                }
            }

            sessionID = newSessionID
            standardOutputPipe = outputPipe
            standardErrorPipe = errorPipe
            runningProcess = SendableProcess(process)
            recordingStartedAt = startedAt

            try process.run()
        } catch {
            cleanUpProcess()
            currentRequest = nil
            state = .failed(message: Self.friendlyMessage(for: error))
        }
    }

    func stop() {
        if let retryTask {
            retryTask.cancel()
            self.retryTask = nil
            currentRequest = nil
            state = .cancelled
            return
        }

        guard let runningProcess, runningProcess.value.isRunning else { return }
        stopWasRequested = true
        state = .stopping
        runningProcess.value.interrupt()

        Task { [weak self, runningProcess] in
            try? await Task.sleep(for: .seconds(8))
            guard runningProcess.value.isRunning else { return }
            runningProcess.value.terminate()
            await MainActor.run {
                self?.appendMessage("Recording process did not stop cleanly and was terminated.")
            }
        }
    }

    func stopForApplicationTermination(completion: @escaping () -> Void) {
        guard state.isActive else {
            completion()
            return
        }

        terminationCompletion = completion
        if finalizationTask != nil {
            return
        }
        if let retryTask {
            retryTask.cancel()
            self.retryTask = nil
            currentRequest = nil
            state = .cancelled
            finishPendingTermination()
            return
        }
        guard runningProcess?.value.isRunning == true else {
            state = .failed(message: "Recording could not be finalized because its process was unavailable.")
            finishPendingTermination()
            return
        }
        stop()
    }

    func reset() {
        guard !state.isActive else { return }
        state = .idle
        progressText = nil
        recentMessages = []
        capturedMediaDuration = 0
        catchUpPhase = nil
        currentRequest = nil
        retryTask?.cancel()
        retryTask = nil
    }

    private func consume(_ text: String, fromStandardError: Bool, sessionID: UUID) {
        guard self.sessionID == sessionID else { return }

        if fromStandardError {
            errorBuffer += text
            consumeCompleteLines(in: &errorBuffer)
        } else {
            outputBuffer += text
            consumeCompleteLines(in: &outputBuffer)
        }
    }

    private func consumeCompleteLines(in buffer: inout String) {
        let parts = buffer.components(separatedBy: .newlines)
        buffer = parts.last ?? ""
        for line in parts.dropLast() {
            handle(line: line)
        }
    }

    private func handle(line: String) {
        guard let event = YTDLPOutputParser.parse(line: line) else { return }
        switch event {
        case .progress(let progress):
            markDownloadStarted()
            progressText = progress
        case .liveStartedAt(let date):
            livestreamStartedAt = date
        case .startedFile:
            markDownloadStarted()
        case .completedFile(let fileURL):
            markDownloadStarted()
            reportedFileURL = fileURL
        case .error(let message):
            lastErrorMessage = message
            appendMessage(message)
        case .message(let message):
            if message.hasPrefix("[download]") || message.hasPrefix("[youtube]") {
                if message.hasPrefix("[download] Destination:") {
                    markDownloadStarted()
                }
                appendMessage(message)
            }
        }
    }

    private func markDownloadStarted() {
        downloadHasStarted = true
        if case .preparing = state {
            state = .recording(startedAt: .now)
        }
        startTimelineMonitoringIfNeeded()
    }

    private func startTimelineMonitoringIfNeeded() {
        guard timelineTask == nil,
              let request = currentRequest,
              request.mode == .fromBeginning else { return }

        let destination = request.destination
        let recordingStartedAt = recordingStartedAt ?? .now
        let ffprobeURL = request.toolchain.ffmpeg.deletingLastPathComponent()
            .appendingPathComponent("ffprobe")
        guard FileManager.default.isExecutableFile(atPath: ffprobeURL.path) else { return }

        timelineTask = Task { [weak self] in
            while !Task.isCancelled {
                if let artifacts = CompletedFileLocator.artifacts(
                    in: destination,
                    modifiedAfter: recordingStartedAt
                ), let duration = await MediaTimelineInspector.capturedDuration(
                    sourceURLs: artifacts.sourceURLs,
                    ffprobeURL: ffprobeURL
                ) {
                    guard !Task.isCancelled else { return }
                    self?.capturedMediaDuration = max(self?.capturedMediaDuration ?? 0, duration)
                    if let startedAt = self?.livestreamStartedAt,
                       MediaTimelineInspector.isAtLiveEdge(
                        capturedDuration: duration,
                        livestreamStartedAt: startedAt
                       ) {
                        self?.catchUpPhase = .live
                    }
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func appendMessage(_ message: String) {
        recentMessages.append(message)
        recentMessages = Array(recentMessages.suffix(8))
    }

    private func processDidTerminate(status: Int32, sessionID: UUID) {
        guard self.sessionID == sessionID else { return }

        flushBuffers()
        let reportedArtifacts = reportedFileURL.flatMap { reportedURL in
            FileManager.default.fileExists(atPath: reportedURL.path)
                ? RecordingArtifacts(sourceURLs: [reportedURL], outputURL: reportedURL)
                : nil
        }
        let fallbackArtifacts = destination.flatMap { destination in
            CompletedFileLocator.artifacts(
                in: destination,
                modifiedAfter: recordingStartedAt ?? .distantFuture
            )
        }
        let artifacts = reportedArtifacts ?? fallbackArtifacts
        let completedFile = artifacts?.outputURL
        let stoppedByUser = stopWasRequested
        let hadStartedDownloading = downloadHasStarted
        let errorMessage = lastErrorMessage
        let ffmpegURL = currentRequest?.toolchain.ffmpeg
        let trimInterruptedTail = stoppedByUser && currentRequest?.mode == .fromBeginning

        cleanUpProcess()
        if Self.shouldRetryNoFormats(
            errorMessage: errorMessage,
            stoppedByUser: stoppedByUser,
            retryAttempt: retryAttempt
        ), let currentRequest {
            scheduleRetry(currentRequest)
            return
        }

        if let artifacts, status == 0 || stoppedByUser, let ffmpegURL {
            currentRequest = nil
            finalize(
                artifacts,
                using: ffmpegURL,
                trimInterruptedTail: trimInterruptedTail
            )
            return
        }

        state = Self.finalState(
            status: status,
            stoppedByUser: stoppedByUser,
            downloadHadStarted: hadStartedDownloading,
            completedFile: completedFile,
            lastErrorMessage: errorMessage
        )
        currentRequest = nil
        finishPendingTermination()
    }

    private func finalize(
        _ artifacts: RecordingArtifacts,
        using ffmpegURL: URL,
        trimInterruptedTail: Bool
    ) {
        state = .stopping
        finalizationTask = Task { [weak self] in
            do {
                let finalizedURL = try await VideoFinalizer.finalize(
                    sourceURLs: artifacts.sourceURLs,
                    outputURL: artifacts.outputURL,
                    ffmpegURL: ffmpegURL,
                    trimInterruptedTail: trimInterruptedTail
                )
                guard !Task.isCancelled else { return }
                self?.state = .completed(fileURL: finalizedURL)
            } catch {
                self?.state = .failed(
                    message: "The recording was saved, but could not be made QuickTime-compatible. \(error.localizedDescription)"
                )
            }
            self?.finalizationTask = nil
            self?.finishPendingTermination()
        }
    }

    private func scheduleRetry(_ request: RecordingRequest) {
        retryAttempt += 1
        state = .preparing
        appendMessage("YouTube returned no formats yet. Retrying in 4 seconds (\(retryAttempt)/2)…")
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.retryTask = nil
            self?.launch(request)
        }
    }

    private func flushBuffers() {
        if !outputBuffer.isEmpty { handle(line: outputBuffer) }
        if !errorBuffer.isEmpty { handle(line: errorBuffer) }
        outputBuffer = ""
        errorBuffer = ""
    }

    private func cleanUpProcess() {
        timelineTask?.cancel()
        timelineTask = nil
        standardOutputPipe?.fileHandleForReading.readabilityHandler = nil
        standardErrorPipe?.fileHandleForReading.readabilityHandler = nil
        standardOutputPipe = nil
        standardErrorPipe = nil
        runningProcess = nil
        sessionID = nil
    }

    private func finishPendingTermination() {
        let completion = terminationCompletion
        terminationCompletion = nil
        completion?()
    }

    private static func friendlyMessage(for error: Error) -> String {
        if let cocoaError = error as? CocoaError, cocoaError.code == .fileWriteNoPermission {
            return "Stream Recorder cannot write to the selected folder. Choose another destination."
        }
        return "Could not start recording: \(error.localizedDescription)"
    }

    nonisolated static func finalState(
        status: Int32,
        stoppedByUser: Bool,
        downloadHadStarted: Bool,
        completedFile: URL?,
        lastErrorMessage: String?
    ) -> RecordingState {
        if let completedFile, status == 0 || stoppedByUser {
            return .completed(fileURL: completedFile)
        }
        if stoppedByUser && !downloadHadStarted {
            return .cancelled
        }
        if stoppedByUser {
            return .failed(message: "Recording stopped, but no video file was found.")
        }
        return .failed(
            message: lastErrorMessage ?? "Recording ended unexpectedly (exit code \(status))."
        )
    }

    nonisolated static func shouldRetryNoFormats(
        errorMessage: String?,
        stoppedByUser: Bool,
        retryAttempt: Int
    ) -> Bool {
        guard !stoppedByUser, retryAttempt < 2, let errorMessage else { return false }
        return errorMessage.localizedCaseInsensitiveContains("no video formats found")
    }
}
