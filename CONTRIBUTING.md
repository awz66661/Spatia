# Contributing

Spatia is intentionally scoped as a disk space visualizer first. Contributions should preserve three product constraints:

- show and explain before offering destructive actions
- keep filesystem access explicit and user initiated
- prefer native macOS behavior over custom cross-platform UI patterns

## Development Loop

Requirements:

- macOS 26 or newer
- Xcode 26 or newer is recommended for app development
- Swift 6.2 or newer

Command Line Tools alone may be enough for package-level builds, but native app development, XCTest, and release builds should use a full Xcode install.

`Package.swift` uses PackageDescription 6.2 so the package can declare `.macOS(.v26)`. The package currently keeps Swift language mode at v5 to avoid mixing the macOS 26 shell refresh with an unrelated Swift 6 concurrency migration.

```sh
./Scripts/check-env.sh
./Scripts/build-debug.sh
./Scripts/test.sh
```

Open `Package.swift` in Xcode when working on the native UI. The package minimum platform is macOS 26.

For a local app-bundle smoke test:

```sh
SKIP_CODESIGN=1 ./Scripts/package-app.sh
```

Scanner benchmarks use generated fixtures and do not touch user folders:

```sh
./Scripts/benchmark-scanner.sh
```

## Pull Requests

Before opening a PR:

- keep changes scoped
- add tests for scanner, treemap, or safety-policy behavior when relevant
- update README, architecture, release, or security notes when changing permissions, release, privacy, or deletion behavior
- avoid introducing telemetry, background daemons, or automatic cleanup logic

Manual UI smoke checks are expected for shell changes:

- native sidebar has exactly one collapse button
- sidebar material extends behind the titlebar and traffic-light area
- scan source, up, and rescan toolbar controls use native toolbar styling
- no-scan, scanned, selected-item, and permission-issue states remain usable in light and dark mode
- selected-item Move to Trash remains blocked or confirmed according to safety policy

## Coding Style

- Swift first
- SwiftUI for shell UI
- AppKit/CoreGraphics for the treemap canvas
- no network calls in the scanner
- no permanent deletion APIs
