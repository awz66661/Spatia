# Spatia

<p align="center">
  <img src="Resources/AppIcon.png" alt="Spatia app icon" width="96">
</p>

[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)
![macOS](https://img.shields.io/badge/macOS-14%2B-black)
![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-orange)
[![CI](https://img.shields.io/badge/CI-workflow%20configured-informational)](.github/workflows/ci.yml)
[![Version](https://img.shields.io/badge/version-see%20VERSION-lightgrey)](VERSION)

Spatia is a native macOS disk space visualizer built around a SpaceSniffer-style treemap.

It is a file space map, not a Mac cleaner. Scans are user initiated, results stay local, and the app does not run telemetry, background indexing, automatic cleanup, or permanent deletion.

## Features

- Scan Downloads, Desktop, Documents, Applications, Home, or a chosen folder.
- Visualize disk usage with a recursive rectangular treemap.
- Navigate into large folders with breadcrumbs.
- Inspect disk usage, logical size, kind, category, modified date, and path.
- Quick Look files, reveal items in Finder, and copy paths.
- Summarize unreadable locations without interrupting the scan.

## Status

Spatia is pre-1.0 macOS software.

- Minimum macOS: 14.
- Current version: see [VERSION](VERSION).
- Distribution target: GitHub Releases.
- Notarization: deferred for early releases.
- App Store: not planned for the first phase.
- Deletion: not implemented; any future deletion must be reversible and limited to Move to Trash.

## Build From Source

Requirements:

- macOS 14 or newer
- Full Xcode recommended
- Swift 5.9 or newer

```sh
./Scripts/check-version.sh
./Scripts/check-env.sh
./Scripts/build-debug.sh
./Scripts/test.sh
```

Create local unsigned artifacts:

```sh
SKIP_CODESIGN=1 ./Scripts/package-app.sh
SKIP_CODESIGN=1 ./Scripts/package-dmg.sh
```

Open `Package.swift` in Xcode for native UI work.

Release builds are created from version tags. Pushes to `main` run CI and unsigned packaging smoke tests only; pushing a tag such as `v0.1.0` creates a draft prerelease with the unsigned DMG and checksum attached.

## Project Layout

- `Sources/Spatia`: macOS app target.
- `Sources/SpatiaCore`: scanner, model, formatting, treemap layout, hit testing, and safety rules.
- `Sources/SpatiaBenchmarks`: synthetic scanner benchmark target.
- `Tests`: scanner, treemap, navigation, category, hit-testing, and safety-policy tests.
- `Docs`: product, architecture, privacy, permissions, release, and development notes.

## Documentation

- [Product](Docs/product.md)
- [Architecture](Docs/architecture.md)
- [Development](Docs/development.md)
- [Permissions](Docs/permissions.md)
- [Scanning](Docs/scanning.md)
- [Roadmap](Docs/roadmap.md)
- [Testing](Docs/testing.md)
- [Release](Docs/release.md)
- [Privacy](Docs/privacy.md)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Contributions should keep filesystem access explicit, preserve local-first privacy, and avoid telemetry, background daemons, permanent deletion, and automatic cleanup logic.

## License

Spatia is licensed under the [Apache License 2.0](LICENSE).
