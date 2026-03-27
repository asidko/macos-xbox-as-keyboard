# Xbox As Keyboard

Free, lightweight macOS menu bar app that maps your game controller buttons to keyboard keys.

![Screenshot](screenshot.jpeg)

## Features

- Map any controller button to any keyboard key (record or select from dropdown)
- Modifier keys (Cmd, Shift, Opt, Ctrl) that combine with other mapped keys
- Macros — chain key combos and text typing into a single button press
- Multiple profiles with color-coded menu bar indicator and instant switching
- Works with Xbox, PlayStation, and any MFi-compatible gamepad
- Lightweight — runs as a menu bar icon, no dock clutter
- Config saved to `~/.config/xboxaskeyboard/config.json`

## Install

Download the latest `.zip` from [Releases](../../releases), unzip, drag to Applications.

Or build from source:

```bash
make install
```

Requires macOS 13+ and Accessibility permission (prompted on first launch).

## Default mappings

D-pad = Arrow keys, A/B/X/Y = A/B/X/Y keys, LB/RB = Page Up/Down, LT/RT = Home/End, Menu = Switch profile

## License

[MIT](LICENSE)
