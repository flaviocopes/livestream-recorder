import Foundation

enum InterruptedTailAnalyzer {
    struct SilenceRange: Equatable {
        let start: TimeInterval
        let end: TimeInterval
    }

    static func trimCutoff(
        fileURL: URL,
        ffmpegURL: URL
    ) async -> TimeInterval? {
        let ffprobeURL = ffmpegURL.deletingLastPathComponent().appendingPathComponent("ffprobe")
        guard FileManager.default.isExecutableFile(atPath: ffprobeURL.path),
              let durations = await MediaTimelineInspector.trackDurations(
                sourceURLs: [fileURL],
                ffprobeURL: ffprobeURL
              ) else {
            return nil
        }

        let gap = abs(durations.video - durations.audio)
        guard gap >= 2 else { return nil }

        let shortestDuration = durations.synchronized
        let silenceOutput = await detectSilence(in: fileURL, using: ffmpegURL)
        if let trailingSilence = trailingSilence(from: silenceOutput),
           trailingSilence.end >= durations.audio - 1,
           trailingSilence.end - trailingSilence.start >= 5 {
            let cutoff = min(shortestDuration, trailingSilence.start)
            return cutoff > 1 ? cutoff : nil
        }
        return shortestDuration > 1 ? shortestDuration : nil
    }

    static func trailingSilence(from output: String) -> SilenceRange? {
        var pendingStart: TimeInterval?
        var lastRange: SilenceRange?

        for line in output.components(separatedBy: .newlines) {
            if let value = value(after: "silence_start:", in: line) {
                pendingStart = value
            }
            if let end = value(after: "silence_end:", in: line),
               let start = pendingStart {
                lastRange = SilenceRange(start: start, end: end)
                pendingStart = nil
            }
        }
        return lastRange
    }

    private static func value(after marker: String, in line: String) -> TimeInterval? {
        guard let markerRange = line.range(of: marker) else { return nil }
        let suffix = line[markerRange.upperBound...].trimmingCharacters(in: .whitespaces)
        let token = suffix.prefix { $0.isNumber || $0 == "." || $0 == "-" }
        return TimeInterval(token)
    }

    private static func detectSilence(in fileURL: URL, using ffmpegURL: URL) async -> String {
        await Task.detached(priority: .utility) {
            let process = Process()
            let errorPipe = Pipe()
            process.executableURL = ffmpegURL
            process.arguments = [
                "-hide_banner", "-nostats",
                "-i", fileURL.path,
                "-map", "0:a:0",
                "-af", "silencedetect=n=-50dB:d=3",
                "-vn", "-f", "null", "-"
            ]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()
                let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                return String(decoding: data, as: UTF8.self)
            } catch {
                return ""
            }
        }.value
    }
}
