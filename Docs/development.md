# Development

## Requirements

- macOS 14 or newer
- Full Xcode is recommended for app development
- Swift 5.9 or newer

Command Line Tools alone may be enough for package-level builds, but native app development, XCTest, and release builds should use a full Xcode install.

## Environment Check

```sh
./Scripts/check-env.sh
```

This checks:

- Swift version
- selected developer directory
- whether `xcodebuild` works
- optional tools such as SwiftFormat and SwiftLint

## Build and Test

```sh
./Scripts/build-debug.sh
./Scripts/test.sh
```

The scripts keep SwiftPM and Clang caches under `.build/` so local sandboxed runs do not depend on writing to user-level cache directories.

## Open in Xcode

Open `Package.swift` in Xcode and run the `Spatia` executable target.

For a full app-bundle workflow, use:

```sh
./Scripts/package-app.sh
```

## Local Tooling Policy

The repository does not require Homebrew or third-party generators for the first phase. SwiftFormat, SwiftLint, and XcodeGen can be introduced later if they materially improve contribution quality.

## Known Local Environment Issue

If Swift reports that the SDK is not supported by the compiler, install or select a matching full Xcode:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Then rerun:

```sh
./Scripts/check-env.sh
./Scripts/test.sh
```
