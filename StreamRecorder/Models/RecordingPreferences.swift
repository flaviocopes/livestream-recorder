import Foundation

enum RecordingPreferences {
    static let modeKey = "recordingMode"
    static let destinationPathKey = "destinationPath"
    static let cookieBrowserKey = "cookieBrowser"

    static var defaultDestination: URL {
        FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Movies")
    }

    static func mode(from rawValue: String) -> RecordingMode {
        RecordingMode(rawValue: rawValue) ?? .currentPoint
    }

    static func cookieBrowser(from rawValue: String) -> CookieBrowser {
        CookieBrowser(rawValue: rawValue) ?? .chrome
    }
}
