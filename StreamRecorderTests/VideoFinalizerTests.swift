import Foundation
import XCTest
@testable import StreamRecorder

final class VideoFinalizerTests: XCTestCase {
    func testRemuxesMPEGTransportStreamIntoRealMP4() async throws {
        let ffmpegURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        guard FileManager.default.isExecutableFile(atPath: ffmpegURL.path) else {
            throw XCTSkip("ffmpeg is not installed at the test path")
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceURL = directory.appendingPathComponent("capture.mp4")
        try makeTransportStream(at: sourceURL, using: ffmpegURL)

        let finalizedURL = try await VideoFinalizer.finalize(
            sourceURL: sourceURL,
            ffmpegURL: ffmpegURL
        )

        XCTAssertEqual(finalizedURL, sourceURL)
        let header = try Data(contentsOf: finalizedURL, options: .mappedIfSafe).prefix(12)
        XCTAssertTrue(String(decoding: header, as: UTF8.self).contains("ftyp"))
    }

    func testMergesSeparateVideoAndAudioComponentsAndRemovesThemAfterVerification() async throws {
        let ffmpegURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        guard FileManager.default.isExecutableFile(atPath: ffmpegURL.path) else {
            throw XCTSkip("ffmpeg is not installed at the test path")
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let videoURL = directory.appendingPathComponent("capture.f299.mp4")
        let audioURL = directory.appendingPathComponent("capture.f140.mp4")
        let outputURL = directory.appendingPathComponent("capture.mp4")
        try makeVideoComponent(at: videoURL, using: ffmpegURL)
        try makeAudioComponent(at: audioURL, using: ffmpegURL)

        let finalizedURL = try await VideoFinalizer.finalize(
            sourceURLs: [videoURL, audioURL],
            outputURL: outputURL,
            ffmpegURL: ffmpegURL
        )

        XCTAssertEqual(finalizedURL, outputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: videoURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: audioURL.path))
        XCTAssertEqual(try streamTypes(in: outputURL), Set(["video", "audio"]))
    }

    func testTrimsLongSilentTailWhenInterruptedTracksAreMismatched() async throws {
        let ffmpegURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        guard FileManager.default.isExecutableFile(atPath: ffmpegURL.path) else {
            throw XCTSkip("ffmpeg is not installed at the test path")
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let videoURL = directory.appendingPathComponent("capture.f137.mp4")
        let audioURL = directory.appendingPathComponent("capture.f140.mp4")
        let outputURL = directory.appendingPathComponent("capture.mp4")
        try runFFmpeg(
            [
                "-f", "lavfi", "-i", "color=c=black:s=320x240:d=8",
                "-an", "-c:v", "libx264", videoURL.path
            ],
            using: ffmpegURL
        )
        try runFFmpeg(
            [
                "-f", "lavfi", "-i", "sine=frequency=440:duration=3",
                "-af", "apad=pad_dur=9", "-t", "12",
                "-vn", "-c:a", "aac", audioURL.path
            ],
            using: ffmpegURL
        )

        _ = try await VideoFinalizer.finalize(
            sourceURLs: [videoURL, audioURL],
            outputURL: outputURL,
            ffmpegURL: ffmpegURL,
            trimInterruptedTail: true
        )

        XCTAssertLessThan(try mediaDuration(in: outputURL), 5)
        XCTAssertEqual(try streamTypes(in: outputURL), Set(["video", "audio"]))
    }

    func testParsesTrailingSilenceRange() {
        let output = """
        [silencedetect] silence_start: 140.641156
        [silencedetect] silence_end: 194.72254 | silence_duration: 54.081383
        """
        XCTAssertEqual(
            InterruptedTailAnalyzer.trailingSilence(from: output),
            .init(start: 140.641156, end: 194.72254)
        )
    }

    private func makeTransportStream(at outputURL: URL, using ffmpegURL: URL) throws {
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = ffmpegURL
        process.arguments = [
            "-hide_banner", "-loglevel", "error", "-y",
            "-f", "lavfi", "-i", "color=c=black:s=320x240:d=1",
            "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo",
            "-shortest",
            "-c:v", "libx264",
            "-c:a", "aac",
            "-f", "mpegts",
            outputURL.path
        ]
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            XCTFail(String(data: data, encoding: .utf8) ?? "Fixture generation failed")
        }
    }


    private func makeVideoComponent(at outputURL: URL, using ffmpegURL: URL) throws {
        try runFFmpeg(
            [
                "-f", "lavfi", "-i", "color=c=black:s=320x240:d=1",
                "-an", "-c:v", "libx264", outputURL.path
            ],
            using: ffmpegURL
        )
    }

    private func makeAudioComponent(at outputURL: URL, using ffmpegURL: URL) throws {
        try runFFmpeg(
            [
                "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo",
                "-t", "1", "-vn", "-c:a", "aac", outputURL.path
            ],
            using: ffmpegURL
        )
    }

    private func runFFmpeg(_ arguments: [String], using ffmpegURL: URL) throws {
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = ffmpegURL
        process.arguments = ["-hide_banner", "-loglevel", "error", "-y"] + arguments
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            XCTFail(String(data: data, encoding: .utf8) ?? "Fixture generation failed")
            return
        }
    }

    private func streamTypes(in fileURL: URL) throws -> Set<String> {
        let ffprobeURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffprobe")
        guard FileManager.default.isExecutableFile(atPath: ffprobeURL.path) else {
            throw XCTSkip("ffprobe is not installed at the test path")
        }
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = ffprobeURL
        process.arguments = [
            "-v", "error",
            "-show_entries", "stream=codec_type",
            "-of", "csv=p=0",
            fileURL.path
        ]
        process.standardOutput = outputPipe
        try process.run()
        process.waitUntilExit()
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
        return Set(output.split(whereSeparator: \.isNewline).map(String.init))
    }

    private func mediaDuration(in fileURL: URL) throws -> TimeInterval {
        let ffprobeURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffprobe")
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = ffprobeURL
        process.arguments = [
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            fileURL.path
        ]
        process.standardOutput = outputPipe
        try process.run()
        process.waitUntilExit()
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return TimeInterval(String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)) ?? .infinity
    }
}
