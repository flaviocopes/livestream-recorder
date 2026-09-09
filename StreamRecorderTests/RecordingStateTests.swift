import XCTest
@testable import StreamRecorder

final class RecordingStateTests: XCTestCase {
    func testOnlyInProgressStatesAreActive() {
        XCTAssertFalse(RecordingState.idle.isActive)
        XCTAssertTrue(RecordingState.preparing.isActive)
        XCTAssertTrue(RecordingState.recording(startedAt: .now).isActive)
        XCTAssertTrue(RecordingState.stopping.isActive)
        XCTAssertFalse(RecordingState.cancelled.isActive)
        XCTAssertFalse(RecordingState.completed(fileURL: URL(filePath: "/tmp/video.mp4")).isActive)
        XCTAssertFalse(RecordingState.failed(message: "No stream").isActive)
    }

    func testStoppingBeforeDownloadStartsIsCancellationNotFailure() {
        XCTAssertEqual(
            RecordingController.finalState(
                status: 2,
                stoppedByUser: true,
                downloadHadStarted: false,
                completedFile: nil,
                lastErrorMessage: nil
            ),
            .cancelled
        )
    }

    func testStoppedRecordingWithAFileIsCompleted() {
        let fileURL = URL(filePath: "/tmp/video.mp4")
        XCTAssertEqual(
            RecordingController.finalState(
                status: 2,
                stoppedByUser: true,
                downloadHadStarted: true,
                completedFile: fileURL,
                lastErrorMessage: nil
            ),
            .completed(fileURL: fileURL)
        )
    }

    func testRetriesTransientNoFormatsErrorOnlyTwice() {
        let message = "[youtube] abc: No video formats found!; please report this issue"

        XCTAssertTrue(
            RecordingController.shouldRetryNoFormats(
                errorMessage: message,
                stoppedByUser: false,
                retryAttempt: 0
            )
        )
        XCTAssertFalse(
            RecordingController.shouldRetryNoFormats(
                errorMessage: message,
                stoppedByUser: false,
                retryAttempt: 2
            )
        )
        XCTAssertFalse(
            RecordingController.shouldRetryNoFormats(
                errorMessage: message,
                stoppedByUser: true,
                retryAttempt: 0
            )
        )
    }
}
