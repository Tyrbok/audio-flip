# AudioFlip

A lightweight macOS menu bar utility for quickly switching audio input and output devices.

## Features

- Lists CoreAudio devices that expose usable input or output channels.
- Shows the current input and output with native menu checkmarks.
- Changes the system default immediately when a device is selected.
- Updates when devices or system defaults change.
- Can be enabled to launch automatically when you log in to macOS.
- Uses CoreAudio directly; it does not record audio or make network requests.

## Screenshot

_Screenshot to be added._

## Requirements

- macOS 14 Sonoma or later.
- Xcode command line tools (Xcode is needed for the project and XCTest suite).

The deployment target is macOS 14 because it includes SwiftUI `MenuBarExtra`, allowing AudioFlip to stay a small native menu bar app. The current Xcode project produces universal builds for Apple Silicon (`arm64`) and Intel (`x86_64`) using Xcode's standard macOS architectures.

The bundle identifier is currently `com.example.AudioFlip`. Replace it with an identifier you control before publishing. The MIT license has a `<COPYRIGHT HOLDER>` placeholder to replace.

## Build and run

```sh
make help
make build
make run
make install
```

AudioFlip is an agent app (`LSUIElement`), so it has no regular window or Dock icon. Debug builds and release ZIPs are unsigned. `make install` uses an ad-hoc local code signature, which does not require a paid Apple Developer account; public distribution still needs Developer ID signing and notarization.

`make install` builds the Release app and copies it to `~/Applications/AudioFlip.app`, where it can be opened from Finder or Spotlight. It signs the installed copy ad hoc by default; override the signing identity with `INSTALL_SIGNING_IDENTITY=...` if needed. This is a direct file copy; it does not use Homebrew. `make uninstall` removes the app from the same location. To choose another destination, pass it to either command, such as `make install INSTALL_DIR=/Applications` and later `make uninstall INSTALL_DIR=/Applications` (macOS may require administrator permission for that location).

The menu's **Launch at login** switch uses macOS Service Management and stays in sync with Login Items. If macOS requires approval, the menu offers a shortcut to Login Items settings. Launch at login applies when you log in to your macOS account.

## Tests and checks

```sh
make test
make check
```

The XCTest suite uses a fake audio manager to test device discovery state, defaults, selection, connection changes, disconnection, failures, and recovery. Real-device behavior still needs the checklist in [MANUAL_TESTING.md](MANUAL_TESTING.md).

## Makefile commands

| Command | Description |
| --- | --- |
| `make help` | Show commands |
| `make build` | Build the debug app |
| `make test` | Run XCTest |
| `make run` | Build, stop any running AudioFlip process, and open the new build |
| `make install` | Build a locally signed Release app and copy it to `~/Applications` (override with `INSTALL_DIR=...`) |
| `make uninstall` | Remove it from `~/Applications` (use the same `INSTALL_DIR` override if applicable) |
| `make clean` | Remove generated `build/` files |
| `make archive` | Create an unsigned Xcode archive |
| `make release` | Build the Release app |
| `make package` | Create a versioned ZIP and print its SHA-256 |
| `make check` | Build and test |

Build products are kept under `build/`, which is ignored by Git.

## Architecture

- `AudioDevice` and `AudioDeviceSnapshot` are the app's small device model.
- `AudioDeviceManaging` is the boundary between application behavior and system audio.
- `CoreAudioDeviceManager` enumerates devices, reads and sets defaults, and owns CoreAudio listeners. It has no SwiftUI dependency.
- `AudioDeviceStore` turns snapshots and change notifications into main-actor UI state.
- `LaunchAtLoginController` registers the app with macOS Service Management and tracks approval status.
- `AudioFlipMenuView` and `AudioFlipApp` provide the menu bar UI.

CoreAudio IDs are retained as identifiers only in snapshots; the manager rechecks a device before setting it, so a disconnected device produces a recoverable error. Listener blocks use a private serial queue and are removed when the manager is released.

## Installation and distribution

### From source

Clone the repository and run `make run`. No external packages are required.

### Release artifacts

`make archive` creates `build/release/AudioFlip.xcarchive`. `make package` creates `build/release/AudioFlip-0.1.0.zip`, containing `AudioFlip.app`, and prints the artifact SHA-256. Update `VERSION` in the Makefile and `MARKETING_VERSION` in the Xcode project together when preparing a later semantic version.

The initial packaging target is unsigned. Before public distribution, configure Developer ID signing and notarization, then archive → sign → notarize → staple → package. No signing identity, team ID, or notarization credential is stored in this repository. The app bundle identifier must also be replaced before release.

The intended Homebrew distribution is a Cask. After publishing a real GitHub release, a custom tap can use `Casks/audioflip.rb` and a URL shaped like:

```ruby
cask "audioflip" do
  version "0.1.0"
  sha256 "<SHA256_FROM_THE_RELEASE_ZIP>"

  url "https://github.com/<GITHUB_USER>/<GITHUB_REPOSITORY>/releases/download/v#{version}/AudioFlip-#{version}.zip"
  name "AudioFlip"
  desc "Quickly switch macOS audio input and output devices"
  homepage "https://github.com/<GITHUB_USER>/<GITHUB_REPOSITORY>"

  app "AudioFlip.app"
end
```

Install from that tap with `brew tap <GITHUB_USER>/tap` followed by `brew install --cask audioflip`. The version, URL, and SHA-256 must match an actual release. Homebrew is not required to build or run the project.

## Release procedure

For the first release, use version `0.1.0`:

1. Replace the bundle identifier and license holder, then confirm the Git working tree is clean.
2. Run `make check`, then `make archive` and `make package`.
3. Configure Developer ID signing and notarization if credentials are available; do not describe an unsigned archive as notarized.
4. Calculate and record the ZIP SHA-256 from `make package`.
5. Create tag `v0.1.0`, publish a GitHub Release with `AudioFlip-0.1.0.zip`, and use that real URL and hash in the custom tap Cask.

## Current limitations

- There is no custom app icon yet; the menu bar uses an SF Symbol.
- The project identifier and license holder are placeholders.
- CoreAudio only exposes devices macOS currently makes available to the system.
- Hardware-dependent behavior must be checked manually before release.
- Public distribution needs Developer ID signing and notarization.

## Contributing

Keep changes small, run `make check`, and update the manual checklist or documentation when behavior changes. The GitHub Actions workflow runs `make check` on macOS for pushes to `main` and pull requests.

## License

MIT. Replace the copyright holder placeholder in [LICENSE](LICENSE) before publication.
