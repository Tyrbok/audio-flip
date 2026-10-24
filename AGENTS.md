# Repository Guidelines

## Project Structure & Module Organization

- `AudioFlip/` contains the app: UI in `AudioFlipMenuView.swift`, state in `AudioDeviceStore.swift`, device types and boundary in `AudioDevice.swift` and `AudioDeviceManaging.swift`, and CoreAudio code in `CoreAudioDeviceManager.swift`.
- `AudioFlipTests/` contains XCTest tests. Use the fake `AudioDeviceManaging` implementation to test behavior without audio hardware; keep CoreAudio-only parsing isolated and testable where practical.
- `AudioFlip.xcodeproj/` contains the project and shared scheme. `README.md` documents the project, `MANUAL_TESTING.md` covers hardware checks, and `Makefile` is the command entry point. There are no separate asset directories.

## Build, Test, and Development Commands

Run Makefile targets from the repository root:

- `make help` lists available commands.
- `make build` compiles the local Debug app; `make run` builds and opens it.
- `make test` runs the XCTest suite; `make check` runs build and tests together.
- `make archive` creates an unsigned Xcode archive; `make package` creates a release ZIP under `build/release/` and prints its SHA-256.
- `make clean` removes generated build artifacts.

Xcode and the macOS SDK are required. Local builds need no release signing credentials.

## Coding Style & Naming Conventions

Use standard Swift conventions and four spaces for indentation. Name types in `UpperCamelCase` and properties, methods, and enum cases in `lowerCamelCase`. Prefer small value types and explicit errors. Keep CoreAudio independent of SwiftUI; use `AudioDeviceManaging` as the system boundary and update UI state on `MainActor`. Avoid unnecessary dependencies and layers. No formatter or linter is configured.

## Testing Guidelines

Add or update XCTest cases in `AudioFlipTests/AudioDeviceStoreTests.swift` for behavior changes. Name tests `test...` and assert state, selections, change notifications, and error recovery. Run `make check` before submitting. For hardware-dependent CoreAudio or menu behavior, follow `MANUAL_TESTING.md`; do not present manual checks as automated coverage.

## Commit & Pull Request Guidelines

Recent commits use short imperative subjects, such as `Handle audio devices without channels`. Follow that style. PRs should explain the change, note CoreAudio or compatibility decisions, and report `make check` results. Include screenshots for menu changes and list pending hardware checks. Link an issue when relevant.

## Security & Configuration

Do not commit signing credentials, secrets, build products, or local Xcode state. Keep the placeholder bundle identifier and unsigned local-build configuration free of personal identifiers until release details are supplied.
