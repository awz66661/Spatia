# Release

Spatia uses GitHub Releases for early distribution. Pushes to `main` run CI only; releases are produced from version tags.

## Version Source

`VERSION` is the canonical project version.

Keep these values aligned before every release:

- `VERSION`: semantic app version in `X.Y.Z` format
- `Resources/Info.plist` `CFBundleShortVersionString`: same value as `VERSION`
- `Resources/Info.plist` `CFBundleVersion`: positive integer build number

Check version consistency locally:

```sh
./Scripts/check-version.sh
```

On GitHub tag builds, the tag must be `v$(cat VERSION)`. For example, `VERSION=0.1.0` must be released with tag `v0.1.0`.

## Early Release Policy

- Tag builds create draft prereleases, not public releases.
- Release artifacts are unsigned unless signing credentials are added later.
- Notarization and stapling are not active yet.
- Do not claim Gatekeeper-friendly distribution until Developer ID signing and notarization are active.
- Users may see unidentified-developer warnings for unsigned, ad-hoc signed, or not-notarized builds.

## CI/CD Shape

- `main` push and pull requests run `.github/workflows/ci.yml`.
- CI checks version consistency, builds, tests, and performs an unsigned DMG smoke package.
- CI and release workflows use macOS 26 runners because the package minimum platform is macOS 26.
- `v*` tags run `.github/workflows/release.yml`.
- Release workflow checks version consistency, builds, tests, packages an unsigned DMG, verifies it, and creates a GitHub draft prerelease.

The release workflow uploads:

```text
dist/Spatia-X.Y.Z.dmg
dist/Spatia-X.Y.Z.dmg.sha256
```

## Local App Bundle

```sh
SKIP_CODESIGN=1 ./Scripts/package-app.sh
```

Output:

```text
dist/Spatia-X.Y.Z.app
```

## Local DMG

```sh
SKIP_CODESIGN=1 ./Scripts/package-dmg.sh
```

Output:

```text
dist/Spatia-X.Y.Z.dmg
dist/Spatia-X.Y.Z.dmg.sha256
```

The DMG contains the versioned app bundle and an `Applications` symlink.

## Package Verification

```sh
DMG_PATH="$(SKIP_CODESIGN=1 ./Scripts/package-dmg.sh | tail -n 1)"
hdiutil verify "${DMG_PATH}"
shasum -a 256 --check "${DMG_PATH}.sha256"
```

## Tag Release Checklist

- Update `VERSION`.
- Update `Resources/Info.plist` `CFBundleShortVersionString` to match `VERSION`.
- Increment `Resources/Info.plist` `CFBundleVersion`.
- Run `./Scripts/check-version.sh`.
- Run `./Scripts/check-env.sh`.
- Run `./Scripts/build-debug.sh`.
- Run `./Scripts/test.sh`.
- Run `./Scripts/benchmark-scanner.sh` and check for large regressions in scan duration or first snapshot latency.
- Run `SKIP_CODESIGN=1 ./Scripts/package-dmg.sh`.
- Complete the [manual smoke test](smoke-test.md).
- Commit and push to `main`.
- Wait for CI to pass on `main`.
- Create an annotated tag, for example `git tag -a v0.1.1 -m "Spatia 0.1.1"`.
- Push the tag, for example `git push origin v0.1.1`.
- Review the draft prerelease created by GitHub Actions.
- Publish only after confirming the unsigned/not-notarized caveat is visible.

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

Do not publish a signed DMG as Gatekeeper-ready until notarization and stapling have been implemented and verified.

## v1.0 Release Target

Before a public v1.0:

- Developer ID signing
- notarization
- stapling
- DMG checksum
- release notes
- privacy statement
- manual smoke test on a clean macOS account

## Deferred

- Sparkle auto-update
- Homebrew Cask
- Mac App Store
