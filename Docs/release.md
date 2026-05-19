# Release

Spatia uses GitHub Releases for early distribution.

## Early Release Policy

- No notarization for early releases.
- Prefer ad-hoc local signing for test bundles.
- Do not claim Gatekeeper-friendly distribution until Developer ID signing and notarization are active.

## Local App Bundle

```sh
./Scripts/package-app.sh
```

Output:

```text
dist/Spatia.app
```

## Local DMG

```sh
./Scripts/package-dmg.sh
```

Output:

```text
dist/Spatia.dmg
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

## Deferred

- Sparkle auto-update
- Homebrew Cask
- Mac App Store
