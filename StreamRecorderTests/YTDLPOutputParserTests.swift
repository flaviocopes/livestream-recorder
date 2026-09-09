import Foundation
import XCTest
@testable import StreamRecorder

final class YTDLPOutputParserTests: XCTestCase {
    func testParsesProgressMarker() {
        XCTAssertEqual(
            YTDLPOutputParser.parse(line: "STREAMRECORDER_PROGRESS: 42.1%|2.3MiB/s|00:15"),
            .progress(" 42.1%|2.3MiB/s|00:15")
        )
    }

    func testParsesLivestreamStartTimestamp() {
        XCTAssertEqual(
            YTDLPOutputParser.parse(line: "STREAMRECORDER_LIVE_START:1785421848"),
            .liveStartedAt(Date(timeIntervalSince1970: 1_785_421_848))
        )
    }

    func testParsesCompletedFileMarker() {
        XCTAssertEqual(
            YTDLPOutputParser.parse(line: "STREAMRECORDER_FILE:/Users/test/Movies/Live.mp4"),
            .completedFile(URL(fileURLWithPath: "/Users/test/Movies/Live.mp4"))
        )
    }

    func testParsesStartedFileMarker() {
        XCTAssertEqual(
            YTDLPOutputParser.parse(line: "STREAMRECORDER_STARTED:/Users/test/Movies/Live.mp4"),
            .startedFile(URL(fileURLWithPath: "/Users/test/Movies/Live.mp4"))
        )
    }

    func testParsesYTDLPError() {
        XCTAssertEqual(
            YTDLPOutputParser.parse(line: "ERROR: [youtube] abc: This live event will begin soon"),
            .error("[youtube] abc: This live event will begin soon")
        )
    }
}
