import XCTest
@testable import StreamRecorder

final class YouTubeURLValidatorTests: XCTestCase {
    func testAcceptsCommonYouTubeURLForms() throws {
        let inputs = [
            "https://www.youtube.com/watch?v=abc123",
            "https://youtube.com/live/abc123",
            "https://youtu.be/abc123",
            "https://www.youtube.com/@channel/live"
        ]

        for input in inputs {
            XCTAssertEqual(try YouTubeURLValidator.validate(input).absoluteString, input)
        }
    }

    func testRejectsMissingSchemeAndOtherHosts() {
        XCTAssertThrowsError(try YouTubeURLValidator.validate("youtube.com/watch?v=abc")) {
            XCTAssertEqual($0 as? StreamURLValidationError, .malformed)
        }
        XCTAssertThrowsError(try YouTubeURLValidator.validate("https://vimeo.com/abc")) {
            XCTAssertEqual($0 as? StreamURLValidationError, .unsupportedHost)
        }
    }
}
