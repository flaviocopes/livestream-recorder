import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var recorder: RecordingController
    @State private var streamURLText = ""
    @AppStorage(RecordingPreferences.modeKey)
    private var storedMode = RecordingMode.currentPoint.rawValue
    @AppStorage(RecordingPreferences.destinationPathKey)
    private var destinationPath = RecordingPreferences.defaultDestination.path
    @AppStorage(RecordingPreferences.cookieBrowserKey)
    private var storedCookieBrowser = CookieBrowser.chrome.rawValue
    @State private var dependencyStatus = ToolchainLocator().inspect()
    @State private var inputError: String?
    @FocusState private var urlFieldIsFocused: Bool

    private var mode: RecordingMode {
        RecordingPreferences.mode(from: storedMode)
    }

    private var destination: URL {
        URL(fileURLWithPath: destinationPath, isDirectory: true)
    }

    private var cookieBrowser: CookieBrowser {
        RecordingPreferences.cookieBrowser(from: storedCookieBrowser)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                if let helpMessage = dependencyStatus.helpMessage {
                    dependencyBanner(helpMessage)
                }

                settings
                urlEntry
                recordingStatus
            }
            .padding(24)
        }
        .frame(width: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            dependencyStatus = ToolchainLocator().inspect()
            urlFieldIsFocused = true
        }
        .task(id: streamURLText) {
            guard !streamURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                inputError = nil
                return
            }
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            startIfPossible()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.red.opacity(0.12))
                Image(systemName: "record.circle.fill")
                    .font(.system(size: 25))
                    .foregroundStyle(.red)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text("Stream Recorder")
                    .font(.title2.weight(.semibold))
                Text("Save a live YouTube stream to your Mac")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
    }

    private func dependencyBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 3) {
                Text("Recording tools required")
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer()

            Button("Check Again") {
                dependencyStatus = ToolchainLocator().inspect()
                if dependencyStatus.toolchain != nil {
                    inputError = nil
                    startIfPossible()
                }
            }
        }
        .padding(14)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Start recording")
                    .font(.headline)

                Picker(
                    "Start recording",
                    selection: Binding(
                        get: { mode },
                        set: { storedMode = $0.rawValue }
                    )
                ) {
                    ForEach(RecordingMode.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(recorder.state.isActive)

                Text(mode == .currentPoint
                     ? "Records from the moment you paste the link."
                     : "Asks YouTube for the available stream from its beginning.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Save to")
                    .font(.headline)

                HStack(spacing: 10) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(destination.path(percentEncoded: false))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Choose…", action: chooseDestination)
                        .disabled(recorder.state.isActive)
                }
                .padding(10)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("YouTube sign-in")
                    .font(.headline)

                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(.secondary)
                    Text("Use cookies from")
                    Spacer()
                    Picker(
                        "Browser",
                        selection: Binding(
                            get: { cookieBrowser },
                            set: { storedCookieBrowser = $0.rawValue }
                        )
                    ) {
                        ForEach(CookieBrowser.allCases) { browser in
                            Text(browser.title).tag(browser)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 155)
                    .disabled(recorder.state.isActive)
                }
                .padding(10)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))

                Text("Be signed into YouTube in this browser. macOS may ask for permission to read its cookies.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var urlEntry: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("YouTube livestream URL")
                    .font(.headline)
                Spacer()
                Text("Paste to start")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                TextField("https://www.youtube.com/watch?v=…", text: $streamURLText)
                    .textFieldStyle(.plain)
                    .focused($urlFieldIsFocused)
                    .disabled(recorder.state.isActive)
                    .onSubmit(startIfPossible)

                if !streamURLText.isEmpty && !recorder.state.isActive {
                    Button {
                        streamURLText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(11)
            .background(.background, in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(inputError == nil ? Color.secondary.opacity(0.25) : .red, lineWidth: 1)
            }

            if let inputError {
                Text(inputError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var recordingStatus: some View {
        switch recorder.state {
        case .idle:
            Label("Ready for a livestream link", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)

        case .preparing:
            statusCard(icon: "hourglass", title: "Preparing recording", detail: "Checking the stream…") {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Button("Cancel") {
                        recorder.stop()
                    }
                }
            }

        case .recording(let startedAt):
            TimelineView(.periodic(from: .now, by: 1)) { context in
                statusCard(
                    icon: "record.circle.fill",
                    iconColor: .red,
                    title: recordingTitle,
                    detail: recordingDetail(since: startedAt, now: context.date)
                ) {
                    Button("Stop Recording", role: .destructive) {
                        recorder.stop()
                    }
                }
            }

        case .stopping:
            statusCard(icon: "hourglass", title: "Finishing recording", detail: "Finalizing the video file…") {
                ProgressView()
                    .controlSize(.small)
            }

        case .cancelled:
            statusCard(
                icon: "xmark.circle",
                title: "Recording cancelled",
                detail: "No video data had been received yet."
            ) {
                Button("Try Again") {
                    recorder.reset()
                    startIfPossible()
                }
            }

        case .completed(let fileURL):
            statusCard(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                title: "Recording saved",
                detail: fileURL.lastPathComponent
            ) {
                HStack {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                    }
                    Button("Record Another") {
                        recorder.reset()
                        streamURLText = ""
                        urlFieldIsFocused = true
                    }
                }
            }

        case .failed(let message):
            statusCard(
                icon: "xmark.octagon.fill",
                iconColor: .red,
                title: "Recording failed",
                detail: message
            ) {
                Button("Try Again") {
                    recorder.reset()
                    startIfPossible()
                }
            }
        }

        if !recorder.recentMessages.isEmpty {
            DisclosureGroup("Recording details") {
                Text(recorder.recentMessages.joined(separator: "\n"))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            }
            .font(.caption)
        }
    }

    private func statusCard<Actions: View>(
        icon: String,
        iconColor: Color = .secondary,
        title: String,
        detail: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
            actions()
        }
        .padding(14)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }

    private func recordingDetail(since startDate: Date, now: Date) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(startDate)))
        let elapsedText = Self.formattedDuration(TimeInterval(elapsed))
        let base: String
        if recorder.catchUpPhase != nil {
            base = "\(Self.formattedDuration(recorder.capturedMediaDuration)) captured  •  \(elapsedText) elapsed"
        } else {
            base = elapsedText
        }
        guard let progress = recorder.progressText else { return base }
        return "\(base)  •  \(progress.replacingOccurrences(of: "|", with: "  •  "))"
    }

    private var recordingTitle: String {
        switch recorder.catchUpPhase {
        case .catchingUp:
            "Catching up"
        case .live:
            "Caught up — recording live"
        case nil:
            "Recording"
        }
    }

    static func formattedDuration(_ seconds: TimeInterval) -> String {
        Duration.seconds(max(0, Int(seconds))).formatted(
            .time(pattern: .hourMinuteSecond(padHourToLength: 2))
        )
    }

    private func startIfPossible() {
        guard !recorder.state.isActive else { return }

        do {
            let streamURL = try YouTubeURLValidator.validate(streamURLText)
            guard let toolchain = dependencyStatus.toolchain else {
                inputError = dependencyStatus.helpMessage
                return
            }

            inputError = nil
            recorder.start(
                streamURL: streamURL,
                mode: mode,
                cookieBrowser: cookieBrowser,
                destination: destination,
                toolchain: toolchain
            )
        } catch {
            inputError = error.localizedDescription
        }
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.title = "Choose Recording Folder"
        panel.prompt = "Choose"
        panel.directoryURL = destination
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let selectedURL = panel.url {
            destinationPath = selectedURL.path
        }
    }
}
