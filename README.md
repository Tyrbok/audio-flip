# AudioFlip

AudioFlip is a native macOS menu bar app for switching audio input and output devices.

## Features

- Switch the system's default input and output devices from the menu bar.
- Adjust the input and output volume when the device exposes a settable volume control.
- Refresh the device list when audio devices or system defaults change.
- Optionally launch at login through macOS Login Items.
- Uses CoreAudio locally. AudioFlip does not record audio or make network requests.

## Requirements

- macOS 14 Sonoma or later.
- A full Xcode installation with the macOS SDK. The Makefile uses `xcodebuild` to build and test the project.
- `make`.

The Xcode project builds for both Apple Silicon (`arm64`) and Intel (`x86_64`). The app is a menu bar extra and does not have a Dock icon or a regular window.

## Build and install

Clone the repository over HTTPS or download its ZIP from GitHub. Public repositories can be downloaded without a GitHub account. Build and open the Debug app with:

```sh
make run
```

To build the Release app and install it in `~/Applications/AudioFlip.app`:

```sh
make install
```

The local install uses an ad-hoc signature and does not require an Apple Developer account. To remove it, run `make uninstall`. Both commands accept `INSTALL_DIR=/path/to/Applications` to use another destination.

`make package` creates an unsigned ZIP under `build/release/`. It is intended for local packaging, not one-click public distribution. Distributing a ready-to-run app to other Macs requires Developer ID signing and notarization to provide the usual Gatekeeper experience.

The app's bundle identifier is currently the template value `com.example.AudioFlip`. Choose a stable, unique identifier before distributing builds beyond your own Macs.

## Commands

Run `make help` to list the available targets.

| Command | Description |
| --- | --- |
| `make build` | Build the Debug app |
| `make run` | Build and open the Debug app |
| `make install` | Build and install the Release app locally |
| `make uninstall` | Remove the locally installed app |
| `make test` | Run the XCTest suite |
| `make check` | Build the app and run the XCTest suite |
| `make archive` | Create an unsigned Xcode archive |
| `make release` | Build the Release app |
| `make package` | Create a versioned ZIP and print its SHA-256 |
| `make clean` | Remove generated build and release artifacts |

Generated files are stored under `build/` and ignored by Git.

## Tests and hardware checks

The XCTest suite uses a fake audio manager to test device discovery, device selection, default changes, volume updates, disconnections, errors, and recovery. It does not require audio hardware.

Run `make test` or `make check` for automated checks. Before distributing a build, follow the real-device checklist in [MANUAL_TESTING.md](MANUAL_TESTING.md); those hardware checks are not covered by XCTest.

GitHub Actions runs `make check` on macOS for pushes to `main` and pull requests.

## Project structure

- `AudioFlip/AudioDevice.swift` defines the device model.
- `AudioFlip/AudioDeviceManaging.swift` defines the boundary between app state and system audio.
- `AudioFlip/CoreAudioDeviceManager.swift` enumerates audio devices and manages CoreAudio properties and listeners.
- `AudioFlip/AudioDeviceStore.swift` exposes device state to the UI on the main actor.
- `AudioFlip/AudioFlipMenuView.swift` and `AudioFlip/AudioFlipApp.swift` implement the menu bar app.
- `AudioFlip/LaunchAtLoginController.swift` manages macOS Login Items integration.
- `AudioFlipTests/` contains automated tests using a fake audio manager.

## Versioning

The current app version is `0.1.0`. Keep `VERSION` in the Makefile and `MARKETING_VERSION` in the Xcode project in sync. Published release tags should use the `vX.Y.Z` format.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development and change guidelines.

## License

AudioFlip is licensed under the MIT License. See [LICENSE](LICENSE).
