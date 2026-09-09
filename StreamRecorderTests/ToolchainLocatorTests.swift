import Foundation
import XCTest
@testable import StreamRecorder

final class ToolchainLocatorTests: XCTestCase {
    func testFindsExecutablesInConfiguredDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        for name in ["yt-dlp", "ffmpeg", "deno"] {
            let tool = directory.appendingPathComponent(name)
            XCTAssertTrue(FileManager.default.createFile(atPath: tool.path, contents: Data()))
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: tool.path
            )
        }

        let status = ToolchainLocator(searchDirectories: [directory]).inspect()

        XCTAssertNotNil(status.toolchain)
        XCTAssertNil(status.helpMessage)
    }

    func testReportsAnActionableMessageForMissingTools() {
        let missingDirectory = URL(fileURLWithPath: "/definitely-not-a-tool-directory")
        let status = ToolchainLocator(searchDirectories: [missingDirectory]).inspect()

        XCTAssertEqual(status.missingTools, ["yt-dlp", "ffmpeg", "deno"])
        XCTAssertEqual(
            status.helpMessage,
            "Install the missing tools with Homebrew: brew install yt-dlp ffmpeg deno"
        )
    }

    func testFindsExecutablesInUserLocalBinWithoutShellPath() throws {
        let homeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let localBin = homeDirectory.appendingPathComponent(".local/bin", isDirectory: true)
        try FileManager.default.createDirectory(at: localBin, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: homeDirectory) }

        for name in ["yt-dlp", "ffmpeg", "deno"] {
            let tool = localBin.appendingPathComponent(name)
            XCTAssertTrue(FileManager.default.createFile(atPath: tool.path, contents: Data()))
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: tool.path
            )
        }

        let status = ToolchainLocator(
            environment: ["PATH": "/usr/bin"],
            homeDirectory: homeDirectory
        ).inspect()

        XCTAssertEqual(status.ytDLP?.resolvingSymlinksInPath(), localBin.appendingPathComponent("yt-dlp").resolvingSymlinksInPath())
        XCTAssertEqual(status.ffmpeg?.resolvingSymlinksInPath(), localBin.appendingPathComponent("ffmpeg").resolvingSymlinksInPath())
        XCTAssertEqual(status.deno?.resolvingSymlinksInPath(), localBin.appendingPathComponent("deno").resolvingSymlinksInPath())
    }

    func testFindsDenoInItsStandardUserInstallDirectory() throws {
        let homeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let localBin = homeDirectory.appendingPathComponent(".local/bin", isDirectory: true)
        let denoBin = homeDirectory.appendingPathComponent(".deno/bin", isDirectory: true)
        try FileManager.default.createDirectory(at: localBin, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: denoBin, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: homeDirectory) }

        for tool in [
            localBin.appendingPathComponent("yt-dlp"),
            localBin.appendingPathComponent("ffmpeg"),
            denoBin.appendingPathComponent("deno")
        ] {
            XCTAssertTrue(FileManager.default.createFile(atPath: tool.path, contents: Data()))
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tool.path)
        }

        let status = ToolchainLocator(
            environment: ["PATH": "/usr/bin"],
            homeDirectory: homeDirectory
        ).inspect()

        XCTAssertEqual(
            status.deno?.resolvingSymlinksInPath(),
            denoBin.appendingPathComponent("deno").resolvingSymlinksInPath()
        )
        XCTAssertNotNil(status.toolchain)
    }
}
