# Architecture

Spatia separates scanning, data modeling, layout, rendering, and actions.

```text
Spatia
├─ Sources/Spatia
│  ├─ AppModel.swift
│  ├─ MainWindowView.swift
│  ├─ TreemapCanvas.swift
│  └─ MacActions.swift
│
└─ Sources/SpatiaCore
   ├─ Model
   ├─ Scanner
   ├─ Treemap
   ├─ Actions
   └─ Formatting
```

## Current Implementation

- `Spatia` is the macOS app target.
- `SpatiaCore` is a platform-light library for scanner, model, layout, formatting, and safety rules.
- `TreemapCanvas` bridges SwiftUI to an AppKit `NSView`.
- The treemap is drawn as one CoreGraphics canvas, not as thousands of SwiftUI views.
- `RecursiveTreemapBuilder` builds 2-3 visible levels from a `FileTreeSnapshot`.
- `SquarifiedTreemapLayout` supports readability-first weighting and a SpaceSniffer-style alternating orientation policy.
- `FileCategoryClassifier` maps scanner metadata, UTType hints, extensions, and protected paths into stable visual categories.
- `FileTreeInsights` derives current-view largest-file and category summaries from immutable snapshots without changing scanner state.
- Current-view and inspector summaries are cached in `AppModel` by snapshot identity and current display root so large snapshots are not repeatedly folded during SwiftUI updates.
- `FileTreeSearch` builds cached search indexes for the scan root or current display root and feeds the toolbar search result panel.
- `MainWindowView` uses a native SwiftUI `NavigationSplitView` shell with the system sidebar toggle, a toolbar breadcrumb path, a full-height material sidebar, and restrained Liquid Glass surfaces for the path and search results.
- `MainWindowView` is split into small SwiftUI files for the sidebar, inspector, toolbar, and detail shell; there is no extra MVVM layer.
- `PathRiskPolicy` centralizes path risk classification for scanner flags, category classification, UI risk state, and trash safety decisions.
- `MacActions` contains macOS-specific actions such as Quick Look, reveal in Finder, copy path, and selected-item Move to Trash.

## Planned Production Shape

```text
SwiftUI NavigationSplitView shell
  -> AppModel / scan state
  -> AppKit TreemapCanvas
  -> CoreGraphics renderer
  -> SpatiaCore layout tiles
  -> SpatiaCore file tree snapshot
```

## Data Flow

```text
User chooses source
  -> FileScanner emits ScanEvent values
  -> ScanAccumulator folds events into FileTreeSnapshot updates
  -> AppModel publishes throttled partial snapshots while scanning
  -> FileTreeInsights derives right-inspector summaries for the current display root
  -> FileTreeSearch derives toolbar search panel results for the scan root or current display root
  -> RecursiveTreemapBuilder chooses visible depth and child containment
  -> SquarifiedTreemapLayout converts siblings into readable-weighted tiles
  -> TreemapNSView draws tiles and handles hit testing
  -> Inspector reads selected FileNode
  -> SafetyPolicy evaluates selected-item Trash availability
```

## Scanner Notes

Spatia defaults to allocated size because users usually care about disk usage rather than logical file length. The inspector shows both disk usage and file size.

The scanner is a Foundation-based implementation that recursively reads the selected directory, aggregates logical and allocated sizes, treats packages as opaque by default, collects unreadable path issues, and does not follow symlink directories.

`FileScanner.scanEvents(root:receive:)` is the single scanner engine. It emits `started`, `nodeDiscovered`, `directoryFinished`, `issue`, and `finished` events. `ScanAccumulator` is the single aggregation path from events to `FileTreeSnapshot`; `scan(root:)` is only the synchronous wrapper around the event pipeline.

Package expansion is an explicit user action. The app scans the selected package with package expansion enabled, appends the package contents into the existing snapshot, updates ancestor sizes, and keeps existing node IDs stable.

Actual recoverable space can differ from displayed allocated size on APFS because of clones, sparse files, compression, purgeable data, iCloud placeholders, local snapshots, and shared APFS container space. The UI must not promise exact recoverable space.

Scanner benchmarks use synthetic fixtures:

```sh
./Scripts/benchmark-scanner.sh
```

These benchmarks are coarse regression signals, not product performance guarantees.

## Near-Term Refactor Points

- Stabilize performance thresholds for the large synthetic benchmark fixtures.
- Add a small visual smoke suite if UI rendering starts to change frequently.
- Add Developer ID signing and notarization before positioning releases as Gatekeeper-ready.
