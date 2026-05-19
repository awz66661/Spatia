# Spatia

[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)
![macOS](https://img.shields.io/badge/macOS-14%2B-black)
![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-orange)
[![CI](https://img.shields.io/badge/CI-workflow%20configured-informational)](.github/workflows/ci.yml)
![Version](https://img.shields.io/badge/version-0.1.0-lightgrey)

Spatia is a native macOS disk space visualizer built around a SpaceSniffer-style treemap.

It helps you see where disk space is going without turning into a cleaner, optimizer, telemetry client, or background indexing service. Spatia scans only the locations you choose and keeps file names, paths, and scan results on your Mac.

## Overview

Spatia is focused on one job: make disk usage understandable. It presents files and folders as a rectangular treemap where larger items take more visible space, then lets you inspect, preview, reveal, or copy paths from the result.

The project is intentionally Mac-native:

- SwiftUI application shell
- AppKit/CoreGraphics treemap canvas
- Foundation-based filesystem scanner
- Swift Package Manager project layout
- GitHub Releases as the early distribution path

## Features

- Scan common locations such as Downloads, Desktop, Documents, Applications, Home, or any folder you choose.
- Visualize disk usage with a recursive rectangular treemap.
- Navigate into large folders with breadcrumb support.
- Inspect selected items with disk usage, logical size, kind, category, modified date, and path.
- Quick Look files, reveal items in Finder, and copy paths.
- Summarize unreadable locations instead of interrupting scans with repeated modal errors.
- Keep packages opaque by default, matching Finder-style expectations for `.app` and similar bundles.

## Current Status

Spatia is an early native macOS project. The visual explorer is usable, but the app should still be treated as pre-1.0 software.

Current boundaries:

- Minimum macOS: macOS 14.
- Current app version: 0.1.0.
- Distribution target: GitHub Releases.
- Notarization: deferred for early releases.
- App Store distribution: not planned for the first phase.
- Deletion support: not implemented; future deletion must be reversible and limited to Move to Trash.

Spatia is not a Mac cleaner and does not provide automatic cleanup recommendations, system optimization claims, permanent deletion, background indexing, cloud sync, or telemetry.

## Install / Build From Source

Public release artifacts are expected to be distributed through GitHub Releases. Until a release is available for your environment, build locally from source.

Requirements:

- macOS 14 or newer
- Full Xcode recommended for native app development and XCTest
- Swift 5.9 or newer

Run the local environment check:

```sh
./Scripts/check-env.sh
```

Build:

```sh
./Scripts/build-debug.sh
```

Test:

```sh
./Scripts/test.sh
```

Create a local unsigned app bundle:

```sh
SKIP_CODESIGN=1 ./Scripts/package-app.sh
```

Create a local unsigned DMG:

```sh
SKIP_CODESIGN=1 ./Scripts/package-dmg.sh
```

Open `Package.swift` in Xcode when working on the native UI.

## Development

The package is split into:

- `Spatia`: the macOS app target.
- `SpatiaCore`: scanner, model, formatting, treemap layout, hit testing, and safety rules.
- `SpatiaBenchmarks`: synthetic scanner benchmark executable.
- `Tests`: unit tests for scanner behavior, treemap layout, navigation, categories, hit testing, and safety policy.
- `Scripts`: local environment, build, test, benchmark, and packaging helpers.

Before opening a pull request, run:

```sh
./Scripts/check-env.sh
./Scripts/build-debug.sh
./Scripts/test.sh
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## Privacy

Spatia is local-first by design.

It does not:

- upload file names
- upload file paths
- collect telemetry
- run a background daemon
- scan locations without user action
- permanently delete files

See [Docs/privacy.md](Docs/privacy.md) for the full privacy statement and [Docs/permissions.md](Docs/permissions.md) for macOS access behavior.

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

Contributions should preserve Spatia's product constraints:

- show and explain disk usage before offering actions
- keep filesystem access explicit and user initiated
- prefer native macOS behavior over custom cross-platform UI patterns
- avoid telemetry, background daemons, permanent deletion, and automatic cleanup logic

Issues and pull requests should include enough macOS, build, scan-source, and privacy/safety context to reproduce the behavior or evaluate the change.

## License

Spatia is licensed under the [Apache License 2.0](LICENSE).
