# Permissions

Spatia uses user-initiated directory scans.

## Default Policy

The first release should not ask for Full Disk Access on launch.

Default entry points:

- Downloads
- Home
- Choose Folder

If protected locations cannot be read, Spatia should keep the partial result and summarize unreadable paths.

## Full Disk Access

Full Disk Access is an advanced path for users who want a more complete scan. It must remain opt-in and explained in plain language.

Suggested copy:

```text
Some protected locations could not be scanned.
You can continue with the current result, or grant Full Disk Access in System Settings for a more complete scan.
```

## Sandboxing

The first GitHub-distributed build is intentionally non-sandboxed. If a sandboxed/App Store variant is added later, it must use:

- `NSOpenPanel` for user-selected roots
- security-scoped bookmarks for persistent access
- clearer messaging around incomplete full-disk scans

## Deletion Permissions

Deletion is limited to selected-item Move to Trash and all decisions route through `SafetyPolicy`.

Blocked locations include system roots, the home folder root, user Library except caches, volume roots, unreadable items, and protected application bundles. Packages, ordinary folders, caches, and items with uncertain recoverable-space behavior require confirmation. Permanent deletion and bulk deletion are not implemented.
