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

## Product Decisions Needed

- Decide when direct flight-controller import becomes approved scope. Current research for USB CDC-ACM on iPadOS is in `RESEARCH.md`; the start view intentionally shows the action as unavailable.
- Decide whether a future transformed/persisted index is justified only after profiling package open, seek, memory, and autosave costs.
- Decide the final project license before adding SPDX license identifiers.
- Identify the Apple Developer Team ID before final signing setup.

## Current Constraints

- Planning only unless implementation is explicitly requested.
- No new external dependency without explicit approval.
- Raw Betaflight logs remain byte-identical and read-only.
- Airframe document state belongs in package metadata; raw-log UI state remains external.
- Bookmarks are not part of document format version 1.
