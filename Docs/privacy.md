# Privacy

Spatia is designed as a local-first file space visualizer.

## Commitments

Spatia does not:

- upload file names
- upload file paths
- collect telemetry
- run a background daemon
- scan locations without user action
- permanently delete files

## Scanning

Spatia scans only the location the user chooses. Some protected locations may be unreadable without Full Disk Access; unreadable locations should be summarized rather than repeatedly surfaced as modal errors.

## Future Features

Any future update mechanism, crash reporting, or analytics proposal must be documented and opt-in before implementation.
