import Foundation

struct RecordingToolchain: Equatable {
    let ytDLP: URL
    let ffmpeg: URL
    let deno: URL
}

struct DependencyStatus: Equatable {
    let ytDLP: URL?
    let ffmpeg: URL?
    let deno: URL?

    var toolchain: RecordingToolchain? {
        guard let ytDLP, let ffmpeg, let deno else { return nil }
        return RecordingToolchain(ytDLP: ytDLP, ffmpeg: ffmpeg, deno: deno)
    }

    var missingTools: [String] {
        var tools: [String] = []
        if ytDLP == nil { tools.append("yt-dlp") }
        if ffmpeg == nil { tools.append("ffmpeg") }
        if deno == nil { tools.append("deno") }
        return tools
    }

    var helpMessage: String? {
        guard !missingTools.isEmpty else { return nil }
        return "Install the missing tools with Homebrew: brew install \(missingTools.joined(separator: " "))"
    }
}

struct ToolchainLocator {
    let searchDirectories: [URL]

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        let pathDirectories = environment["PATH", default: ""]
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0), isDirectory: true) }

        let knownDirectories = [
            homeDirectory.appendingPathComponent(".local/bin", isDirectory: true),
            homeDirectory.appendingPathComponent(".deno/bin", isDirectory: true),
            homeDirectory.appendingPathComponent("bin", isDirectory: true),
            URL(fileURLWithPath: "/opt/homebrew/bin", isDirectory: true),
            URL(fileURLWithPath: "/usr/local/bin", isDirectory: true),
            URL(fileURLWithPath: "/usr/bin", isDirectory: true)
        ]

        var seen = Set<String>()
        searchDirectories = (pathDirectories + knownDirectories).filter {
            seen.insert($0.standardizedFileURL.path).inserted
        }
    }

    init(searchDirectories: [URL]) {
        self.searchDirectories = searchDirectories
    }

    func inspect(fileManager: FileManager = .default) -> DependencyStatus {
        DependencyStatus(
            ytDLP: executable(named: "yt-dlp", fileManager: fileManager),
            ffmpeg: executable(named: "ffmpeg", fileManager: fileManager),
            deno: executable(named: "deno", fileManager: fileManager)
        )
    }

    private func executable(named name: String, fileManager: FileManager) -> URL? {
        searchDirectories
            .map { $0.appendingPathComponent(name, isDirectory: false) }
            .first { fileManager.isExecutableFile(atPath: $0.path) }
    }
}
