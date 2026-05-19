# Security Policy

Spatia is an early local-first macOS disk space visualizer. It scans user-selected filesystem locations and should not transmit file names, file paths, scan results, or usage data.

## Supported Versions

Security fixes are handled on the main development line until stable releases are established.

| Version | Supported |
| --- | --- |
| main | Yes |
| 0.1.x | Best effort |

## Reporting a Vulnerability

If the project has a published GitHub Security Advisory page, please use it. Otherwise, open a minimal public issue that describes the affected area without exposing private paths, private file names, exploit details, or sensitive local data. A maintainer can then coordinate a private follow-up channel.

Useful reports include:

- Spatia reading locations that were not user selected.
- Unexpected network access or telemetry.
- Permanent deletion or unsafe deletion behavior.
- Permission prompts or Full Disk Access guidance that misrepresents what the app does.
- Packaging, signing, or release artifacts that could mislead users about trust or notarization.

## Current Safety Boundaries

- Scans are user initiated.
- Scan results stay local.
- The app does not include telemetry, background indexing, or cloud sync.
- Deletion is not implemented. Future deletion must be limited to Move to Trash and routed through safety policy.
- Early builds must not claim to be notarized or App Store distributed unless that release flow exists and has been verified.
