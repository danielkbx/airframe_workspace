# Active Tasks

Only approved near-term work and unresolved items belong here. Completed work belongs in Git; unapproved ideas belong in `BACKLOG.md`.

## Maintenance

- Keep `ReaderSeriesPresentation` and `AirframeCaptions` mappings synchronized when adding selectable field families or debug meanings. Add conversion and caption tests in the same change.
- Move consumer-facing `ReaderInfoReportBuilder` labels out of `BlackboxReader` without creating a `BlackboxReader` → `AirframeCaptions` dependency cycle. Prefer a semantic report model consumed by `AirframeCaptions`.

## Validation

- Validate Craft roll/pitch signs against the reference viewer on a representative real log.
- Validate Craft motor gauge colors against Graph colors while scrubbing.
- Expand automatic mixer-template checks beyond quad-X using representative bicopter, tricopter, Y4, V-tail, A-tail, Hex, Y6, X8, and octocopter logs.
- Continue compatibility coverage across representative Betaflight versions, multi-log files, GPS logs, and damaged/truncated logs.

## Flight Controller Import Assistant

- Execute the approved commit sequence on `feature/flight-controller-import`, stopping after every commit for review.
- Commit 1: feature branches, pinned Configurator reference, and durable project context.
- Commit 2: generic `MSP` package.
- Commit 3: `FlightController` domain and discovery.
- Commit 4: native assistant shell with mock discovery.
- Commit 5: macOS USB serial connection and Betaflight handshake.
- Commit 6: file-backed FlashFS download with progress, cancellation, retry, and cleanup.
- Commit 7: CLI dump and safe `blackbox_*` settings workflow.
- Commit 8: reusable `FlightControllerImportPayload` and temporary-directory ownership.
- Commit 9: append-capable Airframe format version 2 and materializer.
- Commit 10: new-document consumer from `StartView`.
- Commit 11: CoreBluetooth transport.
- Commit 12: BLE end-to-end integration on macOS and real iOS/iPadOS devices.

## Product Decisions Needed

- Decide whether a future transformed/persisted index is justified only after profiling package open, seek, memory, and autosave costs.
- Decide the final project license before adding SPDX license identifiers.
- Identify the Apple Developer Team ID before final signing setup.

## Current Constraints

- Implementation is approved only for the reviewed Flight Controller Import Assistant milestone; other product work remains planning-only.
- No new external dependency without explicit approval.
- Raw Betaflight logs remain byte-identical and read-only.
- Airframe document state belongs in package metadata; raw-log UI state remains external.
- Bookmarks are not part of document format version 1.
