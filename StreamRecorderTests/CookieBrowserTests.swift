import XCTest
@testable import StreamRecorder

final class CookieBrowserTests: XCTestCase {
    func testUsesYTDLPBrowserNames() {
        XCTAssertEqual(CookieBrowser.chrome.ytDLPArgument, "chrome")
        XCTAssertEqual(CookieBrowser.safari.ytDLPArgument, "safari")
        XCTAssertEqual(CookieBrowser.firefox.ytDLPArgument, "firefox")
        XCTAssertEqual(CookieBrowser.brave.ytDLPArgument, "brave")
        XCTAssertTrue(CookieBrowser.arc.ytDLPArgument.hasPrefix("chrome:"))
    }
}
