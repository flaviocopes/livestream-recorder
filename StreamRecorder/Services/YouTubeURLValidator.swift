import Foundation

enum StreamURLValidationError: LocalizedError, Equatable {
    case empty
    case malformed
    case unsupportedHost

    var errorDescription: String? {
        switch self {
        case .empty:
            "Paste a YouTube livestream URL."
        case .malformed:
            "That does not look like a complete web URL."
        case .unsupportedHost:
            "Stream Recorder currently supports YouTube URLs only."
        }
    }
}

enum YouTubeURLValidator {
    static func validate(_ input: String) throws -> URL {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StreamURLValidationError.empty }
        guard
            let components = URLComponents(string: trimmed),
            let scheme = components.scheme?.lowercased(),
            scheme == "https" || scheme == "http",
            let host = components.host?.lowercased(),
            let url = components.url
        else {
            throw StreamURLValidationError.malformed
        }

        let isYouTube = host == "youtube.com" || host.hasSuffix(".youtube.com")
        let isShortLink = host == "youtu.be" || host.hasSuffix(".youtu.be")
        guard isYouTube || isShortLink else {
            throw StreamURLValidationError.unsupportedHost
        }

        return url
    }
}
