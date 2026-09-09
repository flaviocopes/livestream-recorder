import Foundation

enum CatchUpPhase: Equatable {
    case catchingUp
    case live
}

enum MediaTimelineInspector {
    struct TrackDurations: Equatable {
        let video: TimeInterval
        let audio: TimeInterval

        var synchronized: TimeInterval { min(video, audio) }
    }

    private struct ProbeResult: Decodable {
        struct Stream: Decodable {
            let codecType: String?
            let duration: String?

            enum CodingKeys: String, CodingKey {
                case codecType = "codec_type"
                case duration
            }
        }

        let streams: [Stream]
    }

    static func capturedDuration(
        sourceURLs: [URL],
        ffprobeURL: URL
    ) async -> TimeInterval? {
        await trackDurations(sourceURLs: sourceURLs, ffprobeURL: ffprobeURL)?.synchronized
    }

    static func trackDurations(
        sourceURLs: [URL],
        ffprobeURL: URL
    ) async -> TrackDurations? {
        await Task.detached(priority: .utility) {
            var videoDurations: [TimeInterval] = []
            var audioDurations: [TimeInterval] = []

            for sourceURL in sourceURLs {
                guard let result = probe(sourceURL, using: ffprobeURL) else { continue }
                for stream in result.streams {
                    guard let rawDuration = stream.duration,
                          let duration = TimeInterval(rawDuration),
                          duration.isFinite,
                          duration > 0 else { continue }
                    if stream.codecType == "video" {
                        videoDurations.append(duration)
                    } else if stream.codecType == "audio" {
                        audioDurations.append(duration)
                    }
                }
            }

            guard let videoDuration = videoDurations.max(),
                  let audioDuration = audioDurations.max() else {
                return nil
            }
            return TrackDurations(video: videoDuration, audio: audioDuration)
        }.value
    }

    static func isAtLiveEdge(
        capturedDuration: TimeInterval,
        livestreamStartedAt: Date,
        now: Date = .now,
        safetyMargin: TimeInterval = 20
    ) -> Bool {
        let liveDuration = max(0, now.timeIntervalSince(livestreamStartedAt))
        return liveDuration - capturedDuration <= safetyMargin
    }

    private static func probe(_ sourceURL: URL, using ffprobeURL: URL) -> ProbeResult? {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return nil }
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = ffprobeURL
        process.arguments = [
            "-v", "error",
            "-show_entries", "stream=codec_type,duration",
            "-of", "json",
            sourceURL.path
        ]
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return try JSONDecoder().decode(ProbeResult.self, from: data)
        } catch {
            return nil
        }
    }
}
