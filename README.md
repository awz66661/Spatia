# Spatia

<p align="center">
  <img src="Resources/AppIcon.png" alt="Spatia app icon" width="96">
</p>

[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)
![macOS](https://img.shields.io/badge/macOS-26%2B-black)
![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-orange)
[![CI](https://img.shields.io/badge/CI-workflow%20configured-informational)](.github/workflows/ci.yml)
[![Version](https://img.shields.io/badge/version-see%20VERSION-lightgrey)](VERSION)

Spatia is a native macOS disk space visualizer built around a SpaceSniffer-style treemap. It helps you inspect where local disk space is being used without background indexing, telemetry, automatic cleanup, or permanent deletion.

Spatia is a file space map, not a Mac cleaner. Scans are explicit, user initiated, and kept local.

## Core Capabilities

- Scan Downloads, Desktop, Documents, Applications, Home, or a chosen folder.
- Visualize disk usage with a recursive rectangular treemap.
- Navigate into large folders with the toolbar breadcrumb path and Up button.
- Search the scan or current view by name, path, kind, or category from the toolbar search field.
- Use the right inspector for selected-item details, largest descendant files, and category usage in the current view.
- See partial results during large scans instead of waiting for the full scan to finish.
- Hover treemap tiles for name, size, and path; use mouse, keyboard, or context menu actions.
- Quick Look files, reveal items in Finder, copy paths, and expand opaque packages on demand.
- Move selected items to Trash after safety checks and confirmation.
- Summarize unreadable locations without interrupting the scan.

## Safety Boundaries

- Show and explain disk usage before offering actions.
- Keep filesystem access explicit and user initiated.
- Use safe macOS actions first: Quick Look, Reveal in Finder, Copy Path, and Move to Trash.
- Limit deletion to one selected item, only after safety checks and confirmation.
- Avoid cleanup recommendations, system optimization claims, background indexing, telemetry, cloud sync, permanent deletion, and automatic cleanup.

## Requirements

- macOS 26 or newer.
- Xcode 26 or newer recommended.
- Swift 6.2 or newer.

## Build From Source

Run the local checks:

```sh
./Scripts/check-version.sh
./Scripts/check-env.sh
./Scripts/build-debug.sh
./Scripts/test.sh
```

Open `Package.swift` in Xcode for native UI work.

## Packaging

Create a local ad-hoc signed app bundle:

```sh
./Scripts/package-app.sh
```

Create a local ad-hoc signed DMG:

```sh
./Scripts/package-dmg.sh
```

Release builds are created from version tags. Pushes to `main` run CI and packaging smoke tests only; pushing a tag such as `v0.1.0` creates a draft prerelease with the ad-hoc signed DMG and checksum attached.

## Current Limitations

- Early release artifacts are ad-hoc signed and not notarized.
- Protected folders may produce partial scan results until the user grants Full Disk Access.
- Move to Trash is available only for the selected item after safety checks and confirmation.
- Permanent deletion, bulk deletion, automatic cleanup, and cleanup recommendations are not implemented.
- Displayed allocated size may not equal recoverable space on APFS because of clones, sparse files, compression, purgeable data, iCloud placeholders, and snapshots.

## Privacy And Permissions

Spatia keeps scan results local. It does not upload file names or paths, collect telemetry, run a background daemon, or scan locations without user action.

The first release does not ask for Full Disk Access on launch. Users can scan Downloads, Desktop, Documents, Applications, Home, or a chosen folder. If protected locations cannot be read, Spatia keeps the partial result and reports unreadable paths.

## Project Layout

- `Sources/Spatia`: macOS app target.
- `Sources/SpatiaCore`: scanner, model, formatting, treemap layout, hit testing, and safety rules.
- `Sources/SpatiaBenchmarks`: synthetic scanner benchmark target.
- `Tests`: scanner, treemap, navigation, category, hit-testing, and safety-policy tests.
- `Docs`: architecture and release notes.

## Documentation

- [Architecture](Docs/architecture.md)
- [Release](Docs/release.md)
- [Manual smoke test](Docs/smoke-test.md)
- [Contributing](CONTRIBUTING.md)
- [Security](SECURITY.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Contributions should keep filesystem access explicit, preserve local-first privacy, and avoid telemetry, background daemons, permanent deletion, and automatic cleanup logic.

## License

Spatia is licensed under the [Apache License 2.0](LICENSE).
