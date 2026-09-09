import Foundation

enum RecordingMode: String, CaseIterable, Identifiable {
    case currentPoint
    case fromBeginning

    var id: Self { self }

    var title: String {
        switch self {
        case .currentPoint:
            "From current point"
        case .fromBeginning:
            "From beginning"
        }
    }
}

enum RecordingState: Equatable {
    case idle
    case preparing
    case recording(startedAt: Date)
    case stopping
    case cancelled
    case completed(fileURL: URL)
    case failed(message: String)

    var isActive: Bool {
        switch self {
        case .preparing, .recording, .stopping:
            true
        case .idle, .cancelled, .completed, .failed:
            false
        }
    }
}
