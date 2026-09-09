import Foundation
import XCTest
@testable import StreamRecorder

final class YTDLPCommandBuilderTests: XCTestCase {
    private let toolchain = RecordingToolchain(
        ytDLP: URL(fileURLWithPath: "/opt/homebrew/bin/yt-dlp"),
        ffmpeg: URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg"),
        deno: URL(fileURLWithPath: "/opt/homebrew/bin/deno")
    )
    private let streamURL = URL(string: "https://youtube.com/live/abc123")!
    private let destination = URL(fileURLWithPath: "/Users/test/Movies", isDirectory: true)
    private let date = Date(timeIntervalSince1970: 1_753_878_400)

    func testCurrentPointCommandFiltersForLiveVideoWithoutRewindFlag() {
        let command = YTDLPCommandBuilder.build(
            streamURL: streamURL,
            mode: .currentPoint,
            cookieBrowser: .chrome,
            destination: destination,
            toolchain: toolchain,
            date: date
        )

        XCTAssertEqual(command.executableURL, toolchain.ytDLP)
        XCTAssertTrue(command.arguments.contains("is_live"))
        XCTAssertTrue(command.arguments.contains("chrome"))
        XCTAssertTrue(command.arguments.contains("deno:/opt/homebrew/bin/deno"))
        XCTAssertTrue(command.arguments.contains(toolchain.ffmpeg.path))
        XCTAssertTrue(command.arguments.contains("--no-part"))
        XCTAssertTrue(command.arguments.contains("before_dl:STREAMRECORDER_STARTED:%(filepath)s"))
        XCTAssertTrue(command.arguments.contains("before_dl:STREAMRECORDER_LIVE_START:%(release_timestamp)s"))
        XCTAssertFalse(command.arguments.contains("--live-from-start"))
        XCTAssertFalse(command.arguments.contains("--concurrent-fragments"))
        XCTAssertEqual(command.arguments.last, streamURL.absoluteString)
        XCTAssertTrue(command.arguments.contains { $0.contains("%(title).160B") })
        XCTAssertTrue(command.environment["PATH", default: ""].contains("/opt/homebrew/bin"))
    }

    func testFromBeginningCommandIncludesRewindFlag() {
        let command = YTDLPCommandBuilder.build(
            streamURL: streamURL,
            mode: .fromBeginning,
            cookieBrowser: .safari,
            destination: destination,
            toolchain: toolchain,
            date: date
        )

        XCTAssertTrue(command.arguments.contains("--live-from-start"))
        XCTAssertTrue(command.arguments.contains("safari"))
        let concurrencyIndex = command.arguments.firstIndex(of: "--concurrent-fragments")
        XCTAssertEqual(concurrencyIndex.map { command.arguments[$0 + 1] }, "5")
        let formatIndex = command.arguments.firstIndex(of: "--format")
        let format = formatIndex.map { command.arguments[$0 + 1] }
        XCTAssertTrue(format?.contains("vcodec^=avc1") == true)
        XCTAssertTrue(format?.contains("acodec^=mp4a") == true)
    }

    func testEnrichesFinderStylePathWithToolDirectories() {
        let command = YTDLPCommandBuilder.build(
            streamURL: streamURL,
            mode: .currentPoint,
            cookieBrowser: .chrome,
            destination: destination,
            toolchain: toolchain,
            date: date,
            environment: ["PATH": "/usr/bin:/bin"]
        )

        let paths = command.environment["PATH", default: ""].split(separator: ":").map(String.init)
        XCTAssertTrue(paths.contains("/opt/homebrew/bin"))
        XCTAssertTrue(paths.contains("/usr/bin"))
        XCTAssertTrue(paths.contains("/bin"))
    }
}
