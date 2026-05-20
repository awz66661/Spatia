# Contributing

Spatia is intentionally scoped as a disk space visualizer first. Contributions should preserve three product constraints:

- show and explain before offering destructive actions
- keep filesystem access explicit and user initiated
- prefer native macOS behavior over custom cross-platform UI patterns

## Development Loop

```sh
./Scripts/check-env.sh
./Scripts/build-debug.sh
./Scripts/test.sh
```

Open `Package.swift` in Xcode when working on the native UI. The package minimum platform is macOS 26.

## Pull Requests

Before opening a PR:

- keep changes scoped
- add tests for scanner, treemap, or safety-policy behavior when relevant
- update docs when changing permissions, release, or deletion behavior
- avoid introducing telemetry, background daemons, or automatic cleanup logic

## Coding Style

- Swift first
- SwiftUI for shell UI
- AppKit/CoreGraphics for the treemap canvas
- no network calls in the scanner
- no permanent deletion APIs
