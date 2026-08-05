# Active Tasks

Only approved near-term work and unresolved acceptance gates belong here. Completed work belongs in Git and the current architecture; unapproved ideas belong in [BACKLOG.md](BACKLOG.md).

## Live Acceptance Pending

### Analysis Crosshair Performance

- Verify with a usable CHIRP document that rapid pointer motion redraws only the crosshair layer in Frequency Response Response/Spectrogram and Spectrum Frequency/heatmap modes.
- During a five-second pointer profile, static FFT traces, heatmaps, grids, labels, and response paths must remain flat after initial layout.
- Recheck resize, zoom, snapping, guide/filter highlights, and pointer exit after profiling.

### Inspector Scroll and Hover Stability

- On macOS, confirm Graph, Table, Spectrum, and Step Response inspectors scroll without visible stutter.
- Verify checkbox hit testing and the fixed 500 ms hover-highlight activation.
- Pointer exit, explicit clear, and tap toggles must remain immediate.

### Graph Cache and Playback

- Repeat complete playback followed by broad reverse/random scrubbing on the established large-log fixture.
- Prepared coverage must avoid raw decode for covered ranges; the overview must remain visible until covering detail is ready.
- Confirm the Timeline coverage strip reports active, prepared, and render-ready ranges under `LogContext.cacheLogID`.
- Profile persistent prepared-series restore/encode only if it still causes visible latency or material transient memory amplification. Do not redesign the cache without that evidence.

### Regular-File Airframe Documents

Automated container and lifecycle work is complete. Remaining acceptance is environmental:

- Real iCloud Drive and third-party document-provider open/save/duplicate/export.
- Cross-volume replacement fallback.
- Large real-world document performance and Instruments profiling.
- Exact picker/exporter behavior listed as manual in [DOCUMENT_IO_MATRIX.md](DOCUMENT_IO_MATRIX.md).

## Maintenance

- Keep `ReaderSeriesPresentation` and `AirframeCaptions` mappings synchronized when adding selectable fields or debug meanings; add conversion and caption tests together.
- Move consumer-facing `ReaderInfoReportBuilder` labels out of `BlackboxReader` through a semantic report model, without introducing a `BlackboxReader` to `AirframeCaptions` dependency.

## Validation Inventory

- Map timeline source picker and source colors on the MAYA Betaflight 4.5.2 document on macOS and iPadOS.
- Craft roll/pitch signs against the reference viewer on a representative real log.
- Craft motor gauge colors against Graph colors while scrubbing.
- Mixer-template inference beyond Quad X using representative bicopter, tricopter, Y4, V-tail, A-tail, Hex, Y6, X8, and octocopter logs.
- Compatibility across representative Betaflight versions, multi-log files, GPS logs, and damaged/truncated logs.
- One representative real Betaflight 2026.6.1 log to supplement source-backed compatibility tests.

## Product Decisions Needed

- Final project license before adding SPDX identifiers.
- A transformed or persisted log index only after profiling package open, seek, memory, and autosave costs.

## Current Constraints

- New product work remains planning-only until the user selects a measure from [PLAN.md](PLAN.md) or a backlog item.
- No new external dependency without explicit approval.
- Raw Betaflight logs remain byte-identical and read-only.
- Airframe document state belongs in document metadata; raw-log UI state remains external.
- Bookmarks are not part of document format version 1.
