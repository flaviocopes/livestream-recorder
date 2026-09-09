# Livestream Recorder

Livestream Recorder is a native macOS app for saving live YouTube streams as local MP4 files. Paste a livestream URL, record from the current point or catch up from the available beginning, follow progress in a focused SwiftUI interface, and let the app merge and verify the final recording.

This is one of the software packages I publish with full source. The landing page is https://flaviocopes.com/software/livestream-recorder/.

The code is MIT licensed. You are free to use it, fork it and change it, also commercially.

There is no support. Issues are turned off and there is no roadmap. Forks are welcome.

Record only streams you are authorized to save. Review YouTube's terms and applicable copyright law for your use.

If you point a coding agent at this repository, have it read `AGENTS.md` first.

Current release: **1.0** (`1.0.0` in the Xcode project). See the [Changelog](#changelog) for release notes.

The Swift implementation is a working reference, not a platform limit. Its recording workflow, process management, parsing, finalization, and tests can be rewritten as a Windows or Linux desktop program, a CLI, a web-controlled service, or another interface with an AI coding agent.

## Table of contents

- [What is included](#what-is-included)
- [Quick start](#quick-start)
- [Project map](#project-map)
- [Architecture](#architecture)
- [How it was built](#how-it-was-built)
- [Configuration](#configuration)
- [Distribution](#distribution)
- [Customization](#customization)
- [Security and responsible use](#security-and-responsible-use)
- [Decisions](#decisions)
- [Changelog](#changelog)

## What is included

- Complete Swift 6 and SwiftUI source in `StreamRecorder/`
- Xcode project, shared scheme, and optional XcodeGen specification
- Current-point and from-beginning recording modes
- Browser-cookie selection for streams that require a signed-in YouTube session
- `yt-dlp`, FFmpeg, ffprobe, and Deno discovery and process integration
- Live progress, catch-up status, cancellation, retry, finalization, and Finder reveal flows
- Conservative cleanup for interrupted catch-up recordings
- Unit tests for URL validation, command construction, output parsing, state, file discovery, preferences, timeline inspection, and video finalization
- Human instructions plus dedicated guidance for AI coding agents in `AGENTS.md`

## Quick start

### 1. Prerequisites

- macOS 14 or newer
- Xcode 16 or newer
- Homebrew
- A browser in which you are signed into YouTube

Install the recording tools:

```sh
brew install yt-dlp ffmpeg deno
```

### 2. Build and test

From the repository root:

```sh
xcodebuild -project StreamRecorder.xcodeproj \
  -scheme StreamRecorder \
  -destination 'platform=macOS' \
  test CODE_SIGNING_ALLOWED=NO
```

Open `StreamRecorder.xcodeproj` in Xcode and run the `StreamRecorder` scheme. If you use XcodeGen, `xcodegen generate` recreates the project from `project.yml`.

### 3. Record a stream

Choose whether to start at the current point or request the available stream from its beginning. Pick a destination and the browser whose YouTube cookies may be used, then paste a live YouTube URL. The app starts automatically, reports progress, finalizes an MP4 when stopped, and can reveal the saved file in Finder.

Only record streams you are entitled to save. Review YouTube's terms and applicable copyright law for your use.

## Project map

- `StreamRecorder/App/`: app lifecycle and safe termination
- `StreamRecorder/Views/`: SwiftUI recording interface
- `StreamRecorder/Controllers/`: recording process orchestration and state
- `StreamRecorder/Models/`: preferences, browser choices, and recording state
- `StreamRecorder/Services/`: validation, tool discovery, commands, parsing, media inspection, and finalization
- `StreamRecorderTests/`: unit and tool-assisted media tests
- `project.yml`: optional XcodeGen source of project settings

Read the [Architecture](#architecture) section for the runtime flow, and `AGENTS.md` before pointing an AI coding agent at this repository.

## Architecture

### Overview

Livestream Recorder is a native SwiftUI macOS application that coordinates command-line media tools. The interface collects recording preferences and a YouTube livestream URL. `RecordingController` validates the destination, launches `yt-dlp` directly with structured arguments, consumes machine-readable progress markers, tracks media duration with ffprobe, and asks FFmpeg to produce a verified MP4.

There is no database, backend, account system, analytics service, or embedded API credential.

### Recording flow

1. `ContentView` loads saved mode, destination, and browser preferences.
2. `YouTubeURLValidator` accepts supported YouTube URL shapes.
3. `ToolchainLocator` finds `yt-dlp`, `ffmpeg`, and `deno` in the shell path and common installation locations.
4. `YTDLPCommandBuilder` produces an executable URL, argument array, and enriched process environment.
5. `RecordingController` launches one process and consumes stdout and stderr asynchronously.
6. `YTDLPOutputParser` converts prefixed lines into progress, start-time, file, and error events.
7. In from-beginning mode, `MediaTimelineInspector` uses ffprobe to estimate captured media duration and detect the live edge.
8. On completion or a user stop, `CompletedFileLocator` identifies merged or separate media artifacts.
9. `VideoFinalizer` merges or remuxes the sources into MP4, optionally consulting `InterruptedTailAnalyzer` for a clearly unusable interrupted tail.
10. The UI reports the saved file and can reveal it in Finder.

### Main boundaries

- `Views/ContentView.swift`: presentation and user input
- `Controllers/RecordingController.swift`: process lifecycle and application state
- `Services/YTDLPCommandBuilder.swift`: recording command contract
- `Services/YTDLPOutputParser.swift`: external-process output boundary
- `Services/MediaTimelineInspector.swift`: ffprobe duration and live-edge checks
- `Services/CompletedFileLocator.swift`: output artifact discovery
- `Services/VideoFinalizer.swift`: merge, remux, trim, and output verification
- `Services/InterruptedTailAnalyzer.swift`: conservative interrupted-tail analysis
- `Models/RecordingState.swift`: explicit UI-visible state machine

### Porting model

The product behavior separates cleanly from SwiftUI. A Windows, Linux, or CLI rewrite needs:

- URL and destination validation
- dependency discovery or bundled-tool management
- safe process spawning without shell interpolation
- asynchronous stdout/stderr parsing
- explicit recording and cancellation states
- artifact discovery and FFmpeg finalization
- platform-appropriate credential/session handling
- tests for command construction, parsing, state, and media output

Use the existing tests and service boundaries as the contract. Port behavior rather than translating Swift files line by line.

## How it was built

### Requirements

- macOS 14 or newer
- Xcode 16 or newer
- `yt-dlp`, `ffmpeg`, and `deno` for complete runtime and media-test coverage
- Optional: XcodeGen when regenerating the project from `project.yml`

```sh
brew install yt-dlp ffmpeg deno
```

### Run tests

From the repository root:

```sh
xcodebuild -project StreamRecorder.xcodeproj \
  -scheme StreamRecorder \
  -destination 'platform=macOS' \
  test CODE_SIGNING_ALLOWED=NO
```

FFmpeg/ffprobe integration tests skip when their executables are not installed at a supported path.

### Build

```sh
xcodebuild -project StreamRecorder.xcodeproj \
  -scheme StreamRecorder \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath DerivedData \
  build CODE_SIGNING_ALLOWED=NO
```

The unsigned local result is under `DerivedData/Build/Products/Release/StreamRecorder.app`. `DerivedData/` is gitignored. Do not commit it.

### Regenerate the Xcode project

If you change project settings in `project.yml`:

```sh
brew install xcodegen
xcodegen generate
```

Review the generated project diff and rerun the tests. Keep bundle identifiers, deployment target, target memberships, and the shared scheme consistent.

### Smoke test

Run the app from Xcode, confirm dependency detection, choose a temporary output folder, and use a stream you are authorized to record. Exercise current-point start, from-beginning catch-up, manual stop, successful MP4 playback, Finder reveal, and app quit during recording.

## Configuration

### Runtime tools

The app searches the current `PATH` plus common user, Homebrew, and system locations for:

- `yt-dlp`: stream discovery and download
- `ffmpeg` and `ffprobe`: merging, remuxing, inspection, and finalization
- `deno`: JavaScript runtime used by current YouTube extraction

Change discovery rules in `StreamRecorder/Services/ToolchainLocator.swift`. If you distribute a self-contained build, review each tool's license and update strategy before bundling executables.

### Recording preferences

The app stores three local preferences with `AppStorage`:

- recording mode: current point or available beginning
- destination directory
- browser used for YouTube cookies

Defaults and storage keys live in `StreamRecorder/Models/RecordingPreferences.swift`. No browser cookie contents, stream URLs, or recordings are stored in preferences.

### Browser session

The browser picker maps to `yt-dlp --cookies-from-browser`. You must already be signed into YouTube in the selected browser. macOS or the browser may ask for permission. Supported choices are defined in `CookieBrowser.swift`.

### App identity and signing

This repository uses the placeholder bundle identifiers `com.example.StreamRecorder` and `com.example.StreamRecorderTests`. Replace these in both `project.yml` and the Xcode project before signing or distributing the app. Select your own Apple Developer team and review hardened-runtime, sandbox, entitlement, notarization, and update choices for your distribution model.

### Command behavior

Recording flags and output naming live in `YTDLPCommandBuilder.swift`. Treat changes as behavior changes: update `YTDLPCommandBuilderTests.swift`, test both recording modes, and verify the final output in QuickTime.

## Distribution

Livestream Recorder is a desktop app, so distribution means building, signing, notarizing, and delivering a macOS application rather than deploying a server.

### Personal local build

Open `StreamRecorder.xcodeproj`, select the `StreamRecorder` scheme, and run it from Xcode. The unsigned command-line build is documented in [How it was built](#how-it-was-built).

### Signed macOS release

1. Replace the example bundle identifiers.
2. Select an Apple Developer team and signing certificate.
3. Review whether the app sandbox can be enabled for your intended file and process behavior.
4. Archive a Release build in Xcode.
5. Sign bundled content and third-party tools if you decide to ship them.
6. Notarize the archive with your Apple Developer account.
7. Test the final artifact on a clean Mac without developer tools.

This repository does not contain signing certificates, provisioning data, notarization credentials, or a prebuilt application.

### Later releases

Increment the semantic marketing version and build number, then add a dated entry to the [Changelog](#changelog). Keep the Xcode project, the XcodeGen specification, and this README in sync.

### Dependency strategy

The app expects `yt-dlp`, FFmpeg, and Deno on the user's machine. A commercial distribution can:

- keep Homebrew as an explicit prerequisite;
- guide users to selected executable locations;
- download verified tool releases on first run; or
- bundle tools after reviewing licensing, signing, notarization, update, and security obligations.

Pinning old versions is risky because source-site extraction changes. Define an update and rollback policy.

### Cross-platform delivery

A Windows or Linux port can ship as a native desktop package or CLI. Test executable discovery, browser-session integration, signal handling, path quoting, process-group termination, and media playback on every supported platform.

## Customization

### Rebrand the macOS app

Change the app name and copy in `ContentView.swift`, the display name and bundle identifiers in `project.yml` and the Xcode project, and the asset catalog under `StreamRecorder/Assets.xcassets`. Replace the example identifiers before signing.

### Change the recording workflow

Add quality, codec, audio-only, filename, or output-format controls by extending the preference model and `YTDLPCommandBuilder`. Keep user input as individual process arguments and add tests for every command variant.

### Support more sources

The current validator intentionally accepts YouTube URLs. Add another source behind a provider-specific validation and command layer instead of weakening validation to any URL. Review the provider's terms, authentication model, and output behavior.

### Build a CLI

Reuse the conceptual service boundaries without SwiftUI:

1. parse options and validate the URL and destination;
2. discover or configure the media toolchain;
3. build and launch the process;
4. parse progress markers;
5. handle Ctrl-C as a graceful stop;
6. discover and finalize output;
7. return meaningful exit codes.

The existing parser, command, state, and finalization tests describe the behavior to preserve.

### Port to Windows or Linux

Replace AppKit folder and Finder actions, `AppStorage`, browser choices, executable search paths, and application-termination handling with platform equivalents. The process protocol, recording states, output markers, ffprobe inspection, and FFmpeg finalization remain applicable.

### Create a service

A remote recorder needs an authenticated job API, isolated per-job directories, strict URL controls, concurrency and disk quotas, cancellation, retention, cleanup, and explicit credential handling. Do not upload browser cookie databases from client machines. Use provider-supported authentication or a locally controlled worker when possible.

## Security and responsible use

### Browser sessions

The app can ask `yt-dlp` to read cookies from a locally selected browser. Cookie values are not stored by the app, but they grant account access and must be treated as credentials.

- Never log, export, upload, or commit cookie databases or extracted cookie values.
- Keep browser selection explicit.
- Do not turn cookie access into a hidden background operation.
- Use a separate low-privilege browser profile when appropriate.

### Process execution

Keep executable paths and argument arrays separate. Do not replace `Process` with shell interpolation. Validate URLs and destinations before launching tools, and retain tests for arguments containing spaces or unusual characters.

Only execute trusted `yt-dlp`, FFmpeg, ffprobe, and Deno binaries. If the app downloads tools, verify HTTPS origin, signatures or checksums, version policy, and file permissions.

### Files and lifecycle

Record only into a user-selected writable directory. Avoid overwriting unrelated files. Preserve graceful stop and finalization when the app quits, and make cleanup target only artifacts created by the active recording.

### Signing and distribution

You must choose and review app signing, hardened runtime, sandboxing, notarization, update delivery, and bundled-tool licenses. No certificate, Apple account, browser data, recording, or secret is included in this repository.

### Remote or multi-user versions

A service rewrite adds substantial risk. Require authentication and authorization, isolate jobs and files, restrict destinations and source URLs, enforce time, bandwidth, concurrency, and disk quotas, prevent internal-network URL access, and delete retained media on a documented schedule.

### Legal use

The source makes recording technically possible; it does not grant permission to copy a stream. Record only content you own or are authorized to save, and review platform terms, copyright, privacy, and local law before distribution or use.

## Decisions

### Native SwiftUI interface

SwiftUI provides a small, focused macOS experience with native folder selection, Finder integration, preferences, and application-termination handling. The tradeoff is platform specificity; the recording engine is deliberately separated so it can be ported.

### External media tools

The app uses maintained tools (`yt-dlp`, FFmpeg/ffprobe, and Deno) instead of implementing streaming protocols and codecs. This keeps the source understandable and benefits from upstream format support, but you must install or package compatible tool versions.

### Direct process execution

Commands are launched with `Process.executableURL` and an argument array. No command string is passed through a shell. This makes spaces and user-provided URLs safer and keeps command construction unit-testable.

### Browser cookies are selected, not copied

You choose a supported browser and `yt-dlp` reads its local YouTube session when needed. The app never stores cookie values. macOS may still request browser-data permission, and a cross-platform port needs an equivalent explicit credential model.

### One process for catch-up recording

From-beginning mode keeps one `yt-dlp` process while downloaded media catches up to the live edge. Avoiding a second process reduces timeline gaps and manual fragment stitching.

### Conservative interrupted-tail cleanup

Manual interruption can leave mismatched tracks or a long unusable silent tail. Cleanup runs only for stopped from-beginning recordings and requires evidence before trimming. The tradeoff favors retaining extra media over deleting legitimate silence.

### Tool-assisted integration tests

Pure unit tests cover validation, parsing, state, and command generation. FFmpeg/ffprobe tests create and inspect real media when the tools exist and skip otherwise, keeping the project testable on a clean Xcode machine while still verifying the important media path.

## Changelog

All notable changes to Livestream Recorder are recorded here. Versions follow semantic versioning; the public-facing release label may omit the patch number.

### 1.0.0 - 2026-08-01

Initial public release.

- Records authorized live YouTube streams from the current point or available beginning.
- Supports explicitly selected local browser sessions for streams that require authentication.
- Reports download, media-time, catch-up, retry, cancellation, and finalization progress.
- Discovers `yt-dlp`, FFmpeg, ffprobe, and Deno without embedding personal paths or credentials.
- Locates, merges, remuxes, and verifies MP4 output while conservatively handling interrupted recordings.
- Includes XCTest coverage and complete human and AI-agent documentation for customization or cross-platform ports.
