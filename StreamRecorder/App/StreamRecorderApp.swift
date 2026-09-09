import SwiftUI

@main
struct StreamRecorderApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var applicationDelegate
    @StateObject private var recorder = RecordingController()

    var body: some Scene {
        WindowGroup {
            ContentView(recorder: recorder)
                .onAppear {
                    applicationDelegate.recorder = recorder
                }
        }
        .windowResizability(.contentSize)
    }
}
