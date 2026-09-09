import AppKit

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    weak var recorder: RecordingController?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let recorder, recorder.state.isActive else {
            return .terminateNow
        }

        recorder.stopForApplicationTermination {
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
