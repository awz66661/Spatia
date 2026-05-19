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

## Planned Production Shape

```text
SwiftUI shell
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
  -> SquarifiedTreemapLayout converts visible children into tiles
  -> TreemapNSView draws tiles and handles hit testing
  -> Inspector reads selected FileNode
```

## Near-Term Refactor Points

- Replace one-shot scanning with progressive scan events.
- Move scan aggregation into an actor when progressive updates start.
- Add a render cache once nested depth rendering is introduced.
- Add package expansion as an explicit user action.
