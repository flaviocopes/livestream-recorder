import Foundation
import XCTest
@testable import StreamRecorder

final class MediaTimelineInspectorTests: XCTestCase {
    func testUsesShortestAudioVideoDuration() async throws {
        let ffmpegURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        let ffprobeURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffprobe")
        guard FileManager.default.isExecutableFile(atPath: ffmpegURL.path),
              FileManager.default.isExecutableFile(atPath: ffprobeURL.path) else {
            throw XCTSkip("ffmpeg and ffprobe are required")
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let videoURL = directory.appendingPathComponent("capture.f137.mp4")
        let audioURL = directory.appendingPathComponent("capture.f140.mp4")
        try runFFmpeg(
            ["-f", "lavfi", "-i", "color=c=black:s=160x90:d=4", "-an", "-c:v", "libx264", videoURL.path],
            using: ffmpegURL
        )
        try runFFmpeg(
            ["-f", "lavfi", "-i", "sine=frequency=440:duration=6", "-vn", "-c:a", "aac", audioURL.path],
            using: ffmpegURL
        )

        let duration = await MediaTimelineInspector.capturedDuration(
            sourceURLs: [videoURL, audioURL],
            ffprobeURL: ffprobeURL
        )
        XCTAssertEqual(duration ?? 0, 4, accuracy: 0.2)
    }

    func testDetectsLiveEdgeWithinSafetyMargin() {
        let now = Date(timeIntervalSince1970: 1_000)
        let startedAt = Date(timeIntervalSince1970: 700)

        XCTAssertTrue(
            MediaTimelineInspector.isAtLiveEdge(
                capturedDuration: 285,
                livestreamStartedAt: startedAt,
                now: now,
                safetyMargin: 20
            )
        )
        XCTAssertFalse(
            MediaTimelineInspector.isAtLiveEdge(
                capturedDuration: 250,
                livestreamStartedAt: startedAt,
                now: now,
                safetyMargin: 20
            )
        )
    }

    @MainActor
    func testFormatsCapturedMediaDuration() {
        XCTAssertEqual(ContentView.formattedDuration(194), "00:03:14")
    }

    private func runFFmpeg(_ arguments: [String], using ffmpegURL: URL) throws {
        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = ["-hide_banner", "-loglevel", "error", "-y"] + arguments
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
    }
}
