# Roadmap

## v0.1 Technical Prototype

- [x] Initialize repository
- [x] Add Apache-2.0 license
- [x] Add SwiftPM app and core targets
- [x] Add first native macOS window shell
- [x] Add Foundation scanner prototype
- [x] Add squarified treemap layout
- [x] Add AppKit/CoreGraphics treemap canvas
- [x] Add basic inspector
- [x] Add initial unit tests
- [x] Verify with full Xcode environment
- [x] Add hover state and richer hit testing
- [x] Add double-click directory navigation polish
- [x] Add synthetic benchmark fixtures

## v0.2 Usable Explorer

- [x] Sidebar scan sources
- [x] Permission issue summary view
- [x] Reveal in Finder
- [x] Copy Path
- [x] Quick Look
- [x] File type color mapping
- [x] Better labels and text fitting
- [x] Light/dark/high-contrast polish
- [x] Other small files behavior review
- [x] Recursive SpaceSniffer-style treemap depth
- [x] Readability-first visual weighting
- [x] Unified solid-color three-column utility layout

## v0.3 Safe Actions

- [x] Shared path risk policy used by scanner, category classification, safety decisions, and UI risk state
- [x] Stable risk decisions with explicit `blocked`, `needsConfirmation`, and `allowed` outcomes
- [x] High-risk path blocking for system roots, home root, user Library except caches, application bundles that should not be modified, and other protected locations
- [x] Safety policy tests for system paths, home root, user Library, user caches, packages, application bundles, ordinary files, and ordinary directories
- [x] UI risk state derived from the shared path risk policy instead of scanner-only flags
- [x] Selected-item Move to Trash only; no permanent delete API and no bulk deletion in this milestone
- [x] Confirmation dialog with path, size, item count, and risk reason
- [x] Trash button disabled for blocked items with a visible reason
- [x] Package warning
- [x] Directory deletion warning
- [x] Recoverable-space caveat for APFS clones, sparse files, purgeable files, iCloud placeholders, and shared blocks without promising exact freed space
- [x] Trash result handling for success, cancellation, permission failure, and partial failure
- [x] Post-trash local refresh for the selected item, with full rescan fallback when local reconciliation is unsafe

## v0.4 Explorer Refinement

- [ ] Basic name/path search
- [ ] File type filter chips
- [ ] Search and filter state reflected consistently in sidebar summaries and treemap visible tiles

## v1.0 GitHub Release

- [x] Stable versioned DMG packaging
- [x] Manual GitHub Release checklist
- [x] Signed build path documented
- [x] Full Xcode verification checklist
- [x] CI packaging smoke test
- [ ] README current limitations section for unsigned builds, protected-folder partial scans, no deletion, and APFS recoverable-space caveats
- [ ] Real GitHub Actions status badge instead of static CI configured badge
- [ ] Privacy statement in app and README
- [ ] Architecture docs complete
- [ ] Contribution guide complete
- [ ] Security reporting path documented with a private channel once repository hosting supports it
- [x] Performance baseline documented
- [ ] Notarization decision revisited

## Release Trust Follow-Up

- [ ] Keep early release notes explicit that builds are unsigned and not notarized
- [ ] Add package verification checks that match the current unsigned build policy
- [ ] Revisit Developer ID signing after a developer account is available
- [ ] Add notarization and stapling only after Developer ID signing is available

## Later

- [ ] Sparkle updates
- [ ] Homebrew Cask
- [ ] Progressive scanner actor pipeline
- [ ] Metal renderer if CoreGraphics becomes a bottleneck
- [ ] Optional sandboxed/App Store variant
