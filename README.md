# Xbox As Keyboard

Minimal macOS menu bar app that remaps Xbox controller D-pad to keyboard arrow keys.

## Build & Run

```bash
make run
```

## Install

```bash
make install
```

Installs to `/Applications/XboxAsKeyboard.app`.

## Usage

- 🎮 icon appears in the menu bar
- Click to toggle on/off or quit
- D-pad up/down/left/right maps to keyboard arrow keys
- Requires Accessibility permission (System Settings > Privacy & Security > Accessibility)

## Requirements

- macOS 13+
- Swift 5.9+
- Xbox controller (or any MFi/GCController-compatible gamepad)
