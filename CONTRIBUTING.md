# Contributing

Thanks for your interest in AudioFlip. Focus changes on the app's macOS audio-device behavior, keep CoreAudio independent from SwiftUI, and update the documentation when behavior or commands change.

## Development setup

Use a Mac with macOS 14 or later and a full Xcode installation with the macOS SDK. From the repository root:

```sh
make help
make run
```

## Before submitting a change

- Keep changes focused and use clear, imperative commit subjects.
- Add or update XCTest cases for behavior changes. Tests should use the fake `AudioDeviceManaging` implementation and should not depend on audio hardware.
- Update [MANUAL_TESTING.md](MANUAL_TESTING.md) when a change needs verification with real devices or Login Items.
- Run `make check` and report its result. Do not describe manual hardware checks as automated coverage.
- Include screenshots for menu UI changes when available.

GitHub Actions runs `make check` on macOS for pushes to `main` and pull requests.
