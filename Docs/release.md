# Release

Spatia uses GitHub Releases for early distribution.

## Early Release Policy

- No notarization for early releases.
- Unsigned CI packages are smoke-test artifacts only.
- Prefer ad-hoc local signing for developer test bundles.
- Do not claim Gatekeeper-friendly distribution until Developer ID signing and notarization are active.
- Users may see unidentified-developer warnings for unsigned, ad-hoc signed, or not-notarized builds.

## Local App Bundle

```sh
SKIP_CODESIGN=1 ./Scripts/package-app.sh
```

Output:

```text
dist/Spatia-0.1.0.app
```

## Local DMG

```sh
SKIP_CODESIGN=1 ./Scripts/package-dmg.sh
```

Output:

```text
dist/Spatia-0.1.0.dmg
dist/Spatia-0.1.0.dmg.sha256
```

The DMG contains the versioned app bundle and an `Applications` symlink.

## Signed Build Path

For local signing, provide a signing identity:

```sh
CODESIGN_IDENTITY="Developer ID Application: Example Team (TEAMID)" ./Scripts/package-dmg.sh
```

For ad-hoc signing, omit `CODESIGN_IDENTITY`:

```sh
./Scripts/package-dmg.sh
```

For an unsigned package smoke test:

```sh
SKIP_CODESIGN=1 ./Scripts/package-dmg.sh
```

Notarization and stapling are not active yet. Do not publish a signed DMG as Gatekeeper-ready until the notarization flow has been added and verified.

## Package Verification

```sh
DMG_PATH="$(SKIP_CODESIGN=1 ./Scripts/package-dmg.sh | tail -n 1)"
hdiutil verify "${DMG_PATH}"
shasum -a 256 --check "${DMG_PATH}.sha256"
```

## v1.0 Release Target

Before a public v1.0:

- Developer ID signing
- notarization
- stapling
- DMG checksum
- release notes
- privacy statement
- manual smoke test on a clean macOS account

## GitHub Release Checklist

- Confirm `Resources/Info.plist` has the intended `CFBundleShortVersionString` and `CFBundleVersion`
- Run `./Scripts/check-env.sh`
- Run `./Scripts/build-debug.sh`
- Run `./Scripts/test.sh`
- Run `SKIP_CODESIGN=1 ./Scripts/package-dmg.sh` for CI-equivalent smoke packaging
- For signed releases, run `CODESIGN_IDENTITY="Developer ID Application: ..."` packaging after Developer ID credentials are available
- Verify the DMG with `hdiutil verify`
- Verify the checksum with `shasum -a 256 --check`
- Draft a GitHub Release tagged with the app version
- Upload the `.dmg` and `.dmg.sha256` files
- State clearly whether the release is unsigned, signed but not notarized, or signed and notarized
- Include release notes, known caveats, and any first-run permission guidance

## Deferred

- Sparkle auto-update
- Homebrew Cask
- Mac App Store
