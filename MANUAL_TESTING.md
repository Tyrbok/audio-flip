# Manual verification

Automated tests cover application state through a fake audio manager. Run this checklist on a Mac with real audio hardware before a release:

- [ ] AudioFlip appears in the menu bar and not in the Dock.
- [ ] AudioFlip's app icon appears in Finder and Spotlight.
- [ ] The current output and input devices have visible checkmarks.
- [ ] Selecting an output changes the system default output.
- [ ] Selecting an input changes the system default input.
- [ ] Connecting and removing a USB audio device updates the menu.
- [ ] Changing the default input or output in macOS updates the checkmark.
- [ ] Removing the selected device does not crash AudioFlip.
- [ ] Bluetooth audio and display audio appear when CoreAudio exposes them.
- [ ] Enable Launch at login and confirm AudioFlip appears in System Settings > General > Login Items.
- [ ] With Launch at login enabled, log out and back in and confirm AudioFlip appears in the menu bar.
- [ ] Disable Launch at login and confirm it is removed from the login items list.
- [ ] If macOS requests approval, use the menu shortcut to open Login Items settings and enable AudioFlip.
