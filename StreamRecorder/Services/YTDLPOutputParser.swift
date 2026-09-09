import Foundation

enum YTDLPOutputEvent: Equatable {
    case progress(String)
    case liveStartedAt(Date)
    case startedFile(URL)
    case completedFile(URL)
    case error(String)
    case message(String)
}

enum YTDLPOutputParser {
    private static let progressPrefix = "STREAMRECORDER_PROGRESS:"
    private static let liveStartPrefix = "STREAMRECORDER_LIVE_START:"
    private static let startedPrefix = "STREAMRECORDER_STARTED:"
    private static let filePrefix = "STREAMRECORDER_FILE:"

    static func parse(line: String) -> YTDLPOutputEvent? {
        let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanLine.isEmpty else { return nil }

        if let range = cleanLine.range(of: progressPrefix) {
            return .progress(String(cleanLine[range.upperBound...]))
        }

        if let range = cleanLine.range(of: liveStartPrefix),
           let timestamp = TimeInterval(cleanLine[range.upperBound...]) {
            return .liveStartedAt(Date(timeIntervalSince1970: timestamp))
        }

        if let range = cleanLine.range(of: startedPrefix) {
            return .startedFile(URL(fileURLWithPath: String(cleanLine[range.upperBound...])))
        }

        if let range = cleanLine.range(of: filePrefix) {
            return .completedFile(URL(fileURLWithPath: String(cleanLine[range.upperBound...])))
        }

        if cleanLine.hasPrefix("ERROR:") {
            return .error(cleanLine.replacingOccurrences(of: "ERROR:", with: "")
                .trimmingCharacters(in: .whitespaces))
        }

        return .message(cleanLine)
    }
}
