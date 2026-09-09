import Foundation

enum VideoFinalizerError: LocalizedError {
    case ffmpegFailed(String)
    case emptyOutput
    case invalidMP4

    var errorDescription: String? {
        switch self {
        case .ffmpegFailed(let message):
            "ffmpeg could not finalize the recording: \(message)"
        case .emptyOutput:
            "ffmpeg produced an empty video file."
        case .invalidMP4:
            "ffmpeg did not produce a valid MP4 file."
        }
    }
}

enum VideoFinalizer {
    static func finalize(sourceURL: URL, ffmpegURL: URL) async throws -> URL {
        try await finalize(
            sourceURLs: [sourceURL],
            outputURL: sourceURL,
            ffmpegURL: ffmpegURL,
            trimInterruptedTail: false
        )
    }

    static func finalize(
        sourceURLs: [URL],
        outputURL: URL,
        ffmpegURL: URL,
        trimInterruptedTail: Bool = false
    ) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let temporaryURL = outputURL.deletingLastPathComponent()
                .appendingPathComponent(".\(outputURL.deletingPathExtension().lastPathComponent).finalizing-\(UUID().uuidString).mp4")
            let trimmedURL = outputURL.deletingLastPathComponent()
                .appendingPathComponent(".\(outputURL.deletingPathExtension().lastPathComponent).trimmed-\(UUID().uuidString).mp4")
            defer { try? fileManager.removeItem(at: temporaryURL) }
            defer { try? fileManager.removeItem(at: trimmedURL) }

            let process = Process()
            let errorPipe = Pipe()
            process.executableURL = ffmpegURL
            var arguments = [
                "-hide_banner",
                "-loglevel", "error",
                "-y"
            ]
            for sourceURL in sourceURLs {
                arguments += ["-i", sourceURL.path]
            }
            for index in sourceURLs.indices {
                arguments += ["-map", "\(index):v:0?", "-map", "\(index):a:0?"]
            }
            arguments += [
                "-c", "copy",
                "-movflags", "+faststart",
                temporaryURL.path
            ]
            process.arguments = arguments
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
            guard process.terminationStatus == 0 else {
                throw VideoFinalizerError.ffmpegFailed(errorMessage)
            }

            if trimInterruptedTail,
               let cutoff = await InterruptedTailAnalyzer.trimCutoff(
                fileURL: temporaryURL,
                ffmpegURL: ffmpegURL
               ) {
                try trim(
                    temporaryURL,
                    to: trimmedURL,
                    cutoff: cutoff,
                    using: ffmpegURL
                )
                try fileManager.removeItem(at: temporaryURL)
                try fileManager.moveItem(at: trimmedURL, to: temporaryURL)
            }

            let attributes = try fileManager.attributesOfItem(atPath: temporaryURL.path)
            guard (attributes[.size] as? NSNumber)?.int64Value ?? 0 > 0 else {
                throw VideoFinalizerError.emptyOutput
            }
            let header = try Data(contentsOf: temporaryURL, options: .mappedIfSafe).prefix(32)
            guard String(decoding: header, as: UTF8.self).contains("ftyp") else {
                throw VideoFinalizerError.invalidMP4
            }

            if fileManager.fileExists(atPath: outputURL.path) {
                _ = try fileManager.replaceItemAt(outputURL, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: outputURL)
            }

            for sourceURL in sourceURLs where sourceURL.standardizedFileURL != outputURL.standardizedFileURL {
                try? fileManager.removeItem(at: sourceURL)
            }
            return outputURL
        }.value
    }

    private static func trim(
        _ sourceURL: URL,
        to outputURL: URL,
        cutoff: TimeInterval,
        using ffmpegURL: URL
    ) throws {
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = ffmpegURL
        process.arguments = [
            "-hide_banner", "-loglevel", "error", "-y",
            "-i", sourceURL.path,
            "-t", String(format: "%.6f", cutoff),
            "-map", "0:v:0?",
            "-map", "0:a:0?",
            "-c", "copy",
            "-movflags", "+faststart",
            outputURL.path
        ]
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
        guard process.terminationStatus == 0 else {
            throw VideoFinalizerError.ffmpegFailed(errorMessage)
        }
    }
}
