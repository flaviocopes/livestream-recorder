import Foundation

struct RecordingArtifacts: Equatable {
    let sourceURLs: [URL]
    let outputURL: URL
}

enum CompletedFileLocator {
    private static let videoExtensions = Set(["mp4", "mkv", "webm", "mov", "ts"])

    private struct Candidate {
        let url: URL
        let modified: Date
        let componentBaseName: String?
    }

    static func artifacts(
        in directory: URL,
        modifiedAfter startDate: Date,
        fileManager: FileManager = .default
    ) -> RecordingArtifacts? {
        let candidates = candidates(
            in: directory,
            modifiedAfter: startDate,
            fileManager: fileManager
        )

        let componentGroups = Dictionary(grouping: candidates.compactMap { candidate in
            candidate.componentBaseName.map { ($0, candidate) }
        }, by: { $0.0 })
        let newestCompleteGroup = componentGroups
            .compactMap { baseName, entries -> (String, [Candidate], Date)? in
                let group = entries.map(\.1)
                guard group.count >= 2, let newestDate = group.map(\.modified).max() else {
                    return nil
                }
                return (baseName, group, newestDate)
            }
            .max { $0.2 < $1.2 }

        if let (baseName, group, _) = newestCompleteGroup {
            return RecordingArtifacts(
                sourceURLs: group.sorted { $0.url.path < $1.url.path }.map(\.url),
                outputURL: directory.appendingPathComponent(baseName).appendingPathExtension("mp4")
            )
        }

        guard let newestSingle = candidates
            .filter({ $0.componentBaseName == nil })
            .max(by: { $0.modified < $1.modified }) else {
            return nil
        }
        return RecordingArtifacts(
            sourceURLs: [newestSingle.url],
            outputURL: newestSingle.url
        )
    }

    static func newestVideo(
        in directory: URL,
        modifiedAfter startDate: Date,
        fileManager: FileManager = .default
    ) -> URL? {
        artifacts(
            in: directory,
            modifiedAfter: startDate,
            fileManager: fileManager
        )?.outputURL
    }

    private static func candidates(
        in directory: URL,
        modifiedAfter startDate: Date,
        fileManager: FileManager
    ) -> [Candidate] {
        let resourceKeys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]

        guard let candidates = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return candidates.compactMap { url -> Candidate? in
            guard videoExtensions.contains(url.pathExtension.lowercased()) else { return nil }
            guard !url.lastPathComponent.hasSuffix(".part") else { return nil }
            guard let values = try? url.resourceValues(forKeys: resourceKeys) else { return nil }
            guard values.isRegularFile == true, let modified = values.contentModificationDate else { return nil }
            guard values.fileSize ?? 0 > 0 else { return nil }
            guard modified >= startDate.addingTimeInterval(-1) else { return nil }
            return Candidate(
                url: url,
                modified: modified,
                componentBaseName: componentBaseName(for: url)
            )
        }
    }

    private static func componentBaseName(for url: URL) -> String? {
        let stem = url.deletingPathExtension().lastPathComponent
        guard let range = stem.range(of: #"\.f\d+$"#, options: .regularExpression) else {
            return nil
        }
        return String(stem[..<range.lowerBound])
    }
}
