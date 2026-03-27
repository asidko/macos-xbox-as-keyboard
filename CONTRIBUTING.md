# Contributing

## Build

```bash
make run
```

This imports a dev certificate, builds, signs, and launches the app.

## Dev certificate

The repo includes a self-signed certificate (`certs/dev.p12`) used to sign dev builds. This is **not a security credential** — it's a throwaway cert that ensures macOS Accessibility permissions persist across rebuilds during development. Without it, you'd need to re-grant Accessibility permission after every build.

The cert is auto-imported to your login keychain on first `make build`.

## Project structure

```
Sources/
  main.swift            App delegate, menu bar, controller binding, key simulation
  Config.swift          Data models, profiles, key registry, persistence
  SettingsWindow.swift  Settings UI with tabs, macro editor, key capture
```

Config is saved to `~/.config/xboxaskeyboard/config.json`.

## Commit style

This project uses [conventional commits](https://www.conventionalcommits.org/). PRs are checked automatically.

```
feat: add new feature
fix: fix a bug
chore: maintenance task
docs: documentation only
refactor: code change that doesn't fix a bug or add a feature
```

## Release process

1. Update version in `Info.plist` and `CHANGELOG.md`
2. Commit: `chore: bump version to X.Y.Z`
3. Tag: `git tag vX.Y.Z`
4. Push: `git push --tags`

GitHub Actions builds a universal binary (ARM + Intel) and creates a release with `.dmg`.
