# Manual Smoke Test

Run this checklist before publishing a prerelease or after changing scanner, treemap, sidebar, or file-action behavior.

## Local Checks

```sh
./Scripts/check-version.sh
./Scripts/check-env.sh
./Scripts/build-debug.sh
./Scripts/test.sh
./Scripts/benchmark-scanner.sh
./Scripts/package-dmg.sh
```

Review the benchmark output for every fixture. `firstSnapshotMilliseconds` should stay well below the full scan duration; large regressions mean the progressive scan path needs investigation before release.

## Progressive Scanning

- Scan a large local directory such as `~/Library`, `~/Downloads`, or a source checkout with build artifacts.
- Confirm the treemap appears and grows before the full scan finishes.
- Confirm the sidebar shows current path, file count, folder count, and scanned size while scanning.
- Cancel during the scan and confirm the UI returns immediately to an idle state.
- Rescan the same source and confirm the final counts and status are consistent with the completed scan.

## Navigation And Discovery

- Click large treemap tiles, use the toolbar breadcrumb path, and use the Up toolbar button.
- Toggle the right inspector and confirm selected-item details, largest files, and type usage update for the current view.
- Search from the toolbar field by filename, relative path fragment, file kind, and category.
- Confirm the search result panel opens below the search field and can switch between Scan and Current View scope.
- Click a search or inspector result and confirm the selected item is visible in the treemap path.
- Hover treemap tiles and confirm the tooltip/status show name, size, and path.
- Confirm the sidebar scan options use switch controls for Hidden Files and Expand Packages.

## Actions

- Select a regular file and verify Quick Look, Reveal in Finder, Copy Path, and Move to Trash availability.
- Use the treemap context menu for Enter, Quick Look, Reveal, Copy Path, and Move to Trash.
- Use keyboard navigation: arrow keys move selection, Return enters a folder, Space opens Quick Look, Delete requests Move to Trash, and Esc clears selection.
- Select an application package that was scanned as opaque and run Expand Package. Confirm children appear under that package without rescanning the whole source.
- Try protected or high-risk paths and confirm destructive actions remain blocked or warned by policy.

## Package Artifact

- Mount the ad-hoc signed DMG from `dist`.
- Confirm the Finder window shows the installer background with "Drag Spatia to Applications".
- Confirm `Spatia.app` and `Applications` are positioned correctly and the app can be dragged into Applications.
- Launch `Spatia.app` from the mounted image or copied app bundle.
- Repeat one small scan and one action smoke test.
- Confirm any release notes mention the ad-hoc signed and not-notarized caveat.
