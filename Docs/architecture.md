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
- `GlassPanel` uses `NSGlassEffectView` on macOS 26+ and falls back to `NSVisualEffectView` on macOS 14/15.

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
  -> RecursiveTreemapBuilder chooses visible depth and child containment
  -> SquarifiedTreemapLayout converts siblings into readable-weighted tiles
  -> TreemapNSView draws tiles and handles hit testing
  -> Inspector reads selected FileNode
```

## Near-Term Refactor Points

- Replace one-shot scanning with progressive scan events.
- Move scan aggregation into an actor when progressive updates start.
- Add a render cache if nested redraw cost becomes visible during large scans.
- Add package expansion as an explicit user action.
