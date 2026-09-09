import Foundation

struct RecordingCommand: Equatable {
    let executableURL: URL
    let arguments: [String]
    let environment: [String: String]
}

enum YTDLPCommandBuilder {
    static func build(
        streamURL: URL,
        mode: RecordingMode,
        cookieBrowser: CookieBrowser,
        destination: URL,
        toolchain: RecordingToolchain,
        date: Date = .now,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> RecordingCommand {
        let timestamp = recordingTimestamp(from: date)
        let outputTemplate = destination
            .appendingPathComponent("\(timestamp) %(title).160B [%(id)s].%(ext)s")
            .path

        let format = mode == .fromBeginning
            ? "bestvideo[vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo[vcodec^=avc1]+bestaudio/bestvideo+bestaudio/best"
            : "bestvideo*+bestaudio/best"

        var arguments = [
            "--no-playlist",
            "--match-filter", "is_live",
            "--cookies-from-browser", cookieBrowser.ytDLPArgument,
            "--js-runtimes", "deno:\(toolchain.deno.path)",
            "--newline",
            "--progress",
            "--progress-template", "download:STREAMRECORDER_PROGRESS:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
            "--print", "before_dl:STREAMRECORDER_LIVE_START:%(release_timestamp)s",
            "--print", "before_dl:STREAMRECORDER_STARTED:%(filepath)s",
            "--print", "after_move:STREAMRECORDER_FILE:%(filepath)s",
            "--ffmpeg-location", toolchain.ffmpeg.path,
            "--format", format,
            "--merge-output-format", "mp4",
            "--hls-use-mpegts",
            "--no-part",
            "--output", outputTemplate
        ]

        if mode == .fromBeginning {
            arguments += ["--concurrent-fragments", "5"]
            arguments.append("--live-from-start")
        }

        arguments.append(streamURL.absoluteString)
        return RecordingCommand(
            executableURL: toolchain.ytDLP,
            arguments: arguments,
            environment: processEnvironment(from: environment, toolchain: toolchain)
        )
    }

    private static func processEnvironment(
        from environment: [String: String],
        toolchain: RecordingToolchain
    ) -> [String: String] {
        let existingPaths = environment["PATH", default: ""]
            .split(separator: ":")
            .map(String.init)
        let requiredPaths = [
            toolchain.ytDLP.deletingLastPathComponent().path,
            toolchain.ffmpeg.deletingLastPathComponent().path,
            toolchain.deno.deletingLastPathComponent().path,
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]

        var seen = Set<String>()
        var enriched = environment
        enriched["PATH"] = (requiredPaths + existingPaths)
            .filter { seen.insert($0).inserted }
            .joined(separator: ":")
        return enriched
    }

    private static func recordingTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return formatter.string(from: date)
    }
}
