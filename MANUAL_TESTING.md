# Manual verification

Automated tests cover application state through a fake audio manager. Run this checklist on a Mac with real audio hardware before a release:

- [ ] AudioFlip appears in the menu bar and not in the Dock.
- [ ] The current output and input devices have visible checkmarks.
- [ ] Selecting an output changes the system default output.
- [ ] Selecting an input changes the system default input.
- [ ] Connecting and removing a USB audio device updates the menu.
- [ ] Changing the default input or output in macOS updates the checkmark.
- [ ] Removing the selected device does not crash AudioFlip.
- [ ] Bluetooth audio and display audio appear when CoreAudio exposes them.
