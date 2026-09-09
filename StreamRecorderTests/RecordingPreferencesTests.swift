import XCTest
@testable import StreamRecorder

final class RecordingPreferencesTests: XCTestCase {
    func testRestoresKnownModeAndFallsBackForUnknownValue() {
        XCTAssertEqual(RecordingPreferences.mode(from: "fromBeginning"), .fromBeginning)
        XCTAssertEqual(RecordingPreferences.mode(from: "future-mode"), .currentPoint)
    }

    func testRestoresKnownBrowserAndDefaultsToChrome() {
        XCTAssertEqual(RecordingPreferences.cookieBrowser(from: "safari"), .safari)
        XCTAssertEqual(RecordingPreferences.cookieBrowser(from: "future-browser"), .chrome)
    }
}
