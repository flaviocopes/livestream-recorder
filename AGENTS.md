# Agent guide for Livestream Recorder

## Objective

Help build, customize, or port Livestream Recorder while preserving reliable process control, continuous media output, clear failure states, and safe handling of browser sessions.

## Start here

1. Read `README.md`. The Architecture, Configuration, Security and responsible use, and Changelog sections matter most.
2. The repository root is the Xcode project root: `StreamRecorder.xcodeproj`, `StreamRecorder/`, `StreamRecorderTests/`, and `project.yml` live there.
3. Before a rewrite, ask which operating system, interface, supported sites, output formats, and packaging target the project needs.
4. Never copy browser cookies, account data, recorded media, signing identities, or personal paths into source control.

## Local verification

From the repository root:

```sh
xcodebuild -project StreamRecorder.xcodeproj \
  -scheme StreamRecorder \
  -destination 'platform=macOS' \
  test CODE_SIGNING_ALLOWED=NO
```

Tests that invoke FFmpeg or ffprobe skip when those tools are unavailable. Install `yt-dlp`, `ffmpeg`, and `deno` to exercise the complete workflow.

## Working rules

- Keep `RecordingController` as the owner of process state, retries, cancellation, and finalization.
- Preserve one `yt-dlp` process while a from-beginning recording catches up to the live edge.
- Keep stdout/stderr parsing separate from process orchestration.
- Treat command arguments as an explicit, tested contract; never invoke through an interpolated shell command.
- Keep browser-cookie access opt-in and local. Never export or log cookie contents.
- Preserve destination write checks, graceful interruption, forced-stop fallback, and app-termination finalization.
- Keep media cleanup conservative. Do not trim ordinary silence or assume audio and video lengths always match.
- Update unit tests when changing command flags, output markers, state transitions, file naming, or finalization.
- Treat SwiftUI and macOS as replaceable delivery choices. Preserve behavior and trust boundaries when porting to Windows, Linux, or a CLI.
- Treat `1.0.0` as the initial public release. For every later release, update the Xcode and XcodeGen versions, the tests, and the README (including its Changelog section) together.
- Keep the placeholder bundle identifiers `com.example.StreamRecorder` and `com.example.StreamRecorderTests` unless the task is to rebrand or sign the app.

## Useful task prompts

- “Build this locally, run the tests, and explain any skipped media tests.”
- “Rebrand the macOS app and replace the example bundle identifiers.”
- “Port the recording engine to a cross-platform CLI while preserving the tested command and finalization behavior.”
- “Create a Windows desktop interface around the same process-state model.”
- “Add support for another provider only after reviewing its terms and writing URL-validation and command tests.”
