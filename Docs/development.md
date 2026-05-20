# Development

## Requirements

- macOS 26 or newer
- Full Xcode is recommended for app development
- Swift 6.2 or newer

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
SKIP_CODESIGN=1 ./Scripts/package-app.sh
```

The app bundle name is versioned from `Resources/Info.plist`, for example:

```text
dist/Spatia-0.1.0.app
```

Early local packages are unsigned unless you provide a signing identity. macOS may warn that unsigned or ad-hoc signed builds are from an unidentified developer.

## Full Xcode Verification Checklist

Use this before tagging or distributing a build:

- Select full Xcode: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
- Confirm the selected tools: `xcode-select -p` and `xcodebuild -version`
- Open `Package.swift` in Xcode
- Select the `Spatia` scheme and a local Mac destination
- Build with `Product > Build`
- Run with `Product > Run`
- Run tests with `Product > Test`
- Confirm the app launches without console crashes
- Confirm first-run permission prompts match `Docs/permissions.md`
- Rerun terminal checks: `./Scripts/check-env.sh`, `./Scripts/build-debug.sh`, and `./Scripts/test.sh`
- Verify the Xcode scheme from the command line:

```sh
xcodebuild -scheme Spatia -destination 'platform=macOS' -derivedDataPath DerivedData build
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
