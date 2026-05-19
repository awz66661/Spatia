# Scanning

## Default Size Metric

Spatia defaults to allocated size because users usually care about disk usage rather than logical file length.

The inspector should show both:

- Disk Usage: allocated size
- File Size: logical size

## Current Scanner

The current scanner is a first-pass implementation using Foundation APIs:

- recursively reads the selected directory
- aggregates logical and allocated sizes
- treats packages as opaque by default
- collects unreadable path issues
- does not follow symlink directories

## Synthetic Benchmarks

Run scanner benchmarks without touching user folders:

```sh
./Scripts/benchmark-scanner.sh
```

The benchmark target creates temporary fixtures and prints one JSON row per fixture. Each row includes:

- `fixture`
- `fileCount`
- `folderCount`
- `logicalBytes`
- `allocatedBytes`
- `durationMilliseconds`
- `issueCount`

Initial fixtures cover a balanced tree, a wide directory, opaque packages, and expanded packages. Treat these as coarse baselines for regressions, not as product performance guarantees.

## Package Policy

Packages are shown as one item by default. This keeps `.app`, `.photoslibrary`, and similar bundles aligned with Finder expectations.

Package expansion should become an explicit user action.

## APFS Caveats

Actual recoverable space can differ from displayed allocated size because of:

- APFS clones
- sparse files
- compression
- iCloud placeholders
- local snapshots
- shared APFS container space

The app must avoid promising exact recoverable space.

## Progressive Scanning Plan

The current scanner returns one result at the end. The next scanner milestone is an event stream:

```swift
enum ScanEvent {
    case started(root: URL)
    case discoveredNode(FileNode)
    case updatedSize(nodeID: NodeID, logical: Int64, allocated: Int64)
    case permissionDenied(URL)
    case progress(files: Int, folders: Int, bytes: Int64)
    case finished(ScanSummary)
}
```

UI updates should be throttled to avoid repainting too often during large scans.
