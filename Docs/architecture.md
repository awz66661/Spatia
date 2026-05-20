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
- `MainWindowView` uses a native SwiftUI `NavigationSplitView` shell with the system sidebar toggle, a full-height material sidebar, and restrained glass only on content overlays such as the selected-item inspector.
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
  -> FileScanner scans selected directory
  -> FileTreeSnapshot stores nodes and aggregate sizes
  -> FileTreeInsights derives sidebar summaries for the current display root
  -> RecursiveTreemapBuilder chooses visible depth and child containment
  -> SquarifiedTreemapLayout converts siblings into readable-weighted tiles
  -> TreemapNSView draws tiles and handles hit testing
  -> Inspector reads selected FileNode
  -> SafetyPolicy evaluates selected-item Trash availability
```

## Scanner Notes

Spatia defaults to allocated size because users usually care about disk usage rather than logical file length. The inspector shows both disk usage and file size.

The current scanner is a Foundation-based implementation that recursively reads the selected directory, aggregates logical and allocated sizes, treats packages as opaque by default, collects unreadable path issues, and does not follow symlink directories. Package expansion should become an explicit user action.

Actual recoverable space can differ from displayed allocated size on APFS because of clones, sparse files, compression, purgeable data, iCloud placeholders, local snapshots, and shared APFS container space. The UI must not promise exact recoverable space.

Scanner benchmarks use synthetic fixtures:

```sh
./Scripts/benchmark-scanner.sh
```

These benchmarks are coarse regression signals, not product performance guarantees.

## Near-Term Refactor Points

- Replace one-shot scanning with progressive scan events.
- Move scan aggregation into an actor when progressive updates start.
- Add a render cache if nested redraw cost becomes visible during large scans.
- Add package expansion as an explicit user action.
