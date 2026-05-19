# Spatia

Spatia is a native, open-source macOS disk space visualizer. It helps people understand disk usage with a SpaceSniffer-style rectangular treemap while keeping the product safe, transparent, and Mac-native.

Spatia is not a cleaner, optimizer, or automatic deletion tool. It starts as a visual file space map.

## Project Decisions

- Product name: Spatia
- Minimum macOS: macOS 14
- Distribution: GitHub Releases
- Notarization: deferred for early releases
- App Store: not planned for the first phase
- UI: SwiftUI shell with an AppKit/CoreGraphics treemap canvas
- Rendering: CoreGraphics first, Metal later if needed
- Default size metric: allocated size
- Deletion policy: Move to Trash only, planned after the visual explorer is stable
- License: Apache-2.0

## Current State

This repository is initialized as a Swift Package with:

- `Spatia`: native macOS app target
- `SpatiaCore`: scanner, data model, recursive treemap layout, file categories, and safety policy
- `SpatiaCoreTests`: focused unit tests for scanner fixtures, treemap behavior, categories, hit testing, and safety rules
- `Docs`: product, architecture, permissions, roadmap, testing, and release notes
- `Scripts`: local environment check, build, test, and GitHub Release packaging helpers

The current explorer build includes common scan sources, a compatible glass sidebar and inspector, recursive SpaceSniffer-style treemap rendering, Quick Look, Reveal in Finder, Copy Path, and a consolidated permission issue summary.

## Local Development

Run the environment check first:

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

Create a local `.app` bundle:

```sh
./Scripts/package-app.sh
```

Create a local DMG for a GitHub Release draft:

```sh
./Scripts/package-dmg.sh
```

## Privacy Commitments

Spatia does not:

- upload file names
- upload file paths
- collect telemetry
- run a background daemon
- delete files permanently
- scan locations without user action

See [Docs/privacy.md](Docs/privacy.md).

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

## License

Apache-2.0. See [LICENSE](LICENSE).
