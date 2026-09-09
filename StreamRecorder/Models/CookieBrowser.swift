import Foundation

enum CookieBrowser: String, CaseIterable, Identifiable {
    case chrome
    case safari
    case firefox
    case brave
    case arc

    var id: Self { self }

    var title: String {
        switch self {
        case .chrome: "Google Chrome"
        case .safari: "Safari"
        case .firefox: "Firefox"
        case .brave: "Brave"
        case .arc: "Arc"
        }
    }

    var ytDLPArgument: String {
        switch self {
        case .chrome: return "chrome"
        case .safari: return "safari"
        case .firefox: return "firefox"
        case .brave: return "brave"
        case .arc:
            let profile = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Arc/User Data/Default")
                .path
            return "chrome:\(profile)"
        }
    }
}
