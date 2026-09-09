import Foundation
import XCTest
@testable import StreamRecorder

final class CompletedFileLocatorTests: XCTestCase {
    func testFindsNewestCompletedVideoCreatedAfterRecordingStarted() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let start = Date.now
        let older = directory.appendingPathComponent("older.mp4")
        let newest = directory.appendingPathComponent("newest.mp4")
        let partial = directory.appendingPathComponent("unfinished.mp4.part")
        FileManager.default.createFile(atPath: older.path, contents: Data([1]))
        FileManager.default.createFile(atPath: newest.path, contents: Data([1]))
        FileManager.default.createFile(atPath: partial.path, contents: Data([1]))
        try FileManager.default.setAttributes(
            [.modificationDate: start.addingTimeInterval(-60)],
            ofItemAtPath: older.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: start.addingTimeInterval(2)],
            ofItemAtPath: newest.path
        )

        XCTAssertEqual(
            CompletedFileLocator.newestVideo(in: directory, modifiedAfter: start)?
                .resolvingSymlinksInPath(),
            newest.resolvingSymlinksInPath()
        )
    }

    func testGroupsSeparateYTDLPVideoAndAudioComponents() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let video = directory.appendingPathComponent("Livestream.f299.mp4")
        let audio = directory.appendingPathComponent("Livestream.f140.mp4")
        FileManager.default.createFile(atPath: video.path, contents: Data([1]))
        FileManager.default.createFile(atPath: audio.path, contents: Data([1]))

        let artifacts = CompletedFileLocator.artifacts(
            in: directory,
            modifiedAfter: Date.now.addingTimeInterval(-5)
        )

        XCTAssertEqual(
            Set((artifacts?.sourceURLs ?? []).map { $0.resolvingSymlinksInPath() }),
            Set([video, audio].map { $0.resolvingSymlinksInPath() })
        )
        XCTAssertEqual(
            artifacts?.outputURL.resolvingSymlinksInPath(),
            directory.appendingPathComponent("Livestream.mp4").resolvingSymlinksInPath()
        )
    }

    func testDoesNotTreatOneFormatComponentAsACompleteRecording() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let component = directory.appendingPathComponent("Livestream.f299.mp4")
        FileManager.default.createFile(atPath: component.path, contents: Data([1]))

        XCTAssertNil(
            CompletedFileLocator.artifacts(
                in: directory,
                modifiedAfter: Date.now.addingTimeInterval(-5)
            )
        )
    }
}
