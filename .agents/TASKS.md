# Active Tasks

Only approved near-term work and unresolved acceptance gates belong here. Completed work belongs in Git and the current architecture; unapproved ideas belong in [BACKLOG.md](BACKLOG.md).

## Completed: Action-Based Presets Foundation

- The native toolbar exposes Default first and generation-2 user presets alphabetically immediately before the inspector toggle, without selection or dirty affordances.
- A divided `Save Current Setup…` menu action opens a compact modal matching Airframe's Settings presentation. A native `Save As` dropdown chooses New Preset or an existing user preset to overwrite; Default is never offered, and the dropdown is omitted while no user presets exist. New Preset shows the name field; an overwrite target instead shows an explicit named overwrite notice. The primary action is consistently `Save`.
- `Manage Presets…` remains visible below Save and is disabled only while no user preset exists. Its native platform modal excludes Default, supports transient checkbox-based multiple selection plus a leading visually unlabeled three-state checkbox, renames a user preset in place after double-clicking its name, atomically deletes after singular/plural confirmation, exports the selection together through one native Save dialog, and imports through a native Open panel. The same manager is available from the active document's View menu and stays disabled there without user presets.
- Portable export/import uses the unambiguous `.airframepreset` extension with the new `com.kumkju.airframe.preset-file` UTI conforming to `public.data` and a deterministic generation-1 multi-preset JSON payload. The opaque system conformance preserves Airframe's file identity instead of inviting text-editor presentation; the fresh UTI prevents existing Launch Services registrations from retaining either the former `.apf` association or JSON conformance. Opening an archive, `File > Import Presets…`, or the management import button imports it atomically after native per-name conflict decisions and acknowledges a nonzero imported count. Former `.apf` and single-preset files are rejected without migration.
- Applying a preset is an atomic one-shot copy into self-contained document state. The immutable app Default resets only portable analysis configuration.
- The last manually applied preset is remembered locally and initializes truly new documents exactly once; invalid or missing records normalize to Default, while existing documents retain precedence.
- Preset generation 2 uses compact versioned binary property-list storage and the existing iCloud KVS mirror. Legacy preset libraries and preset-bound document appearance are ignored without migration.
- Ensure the built-in Default preset selects both Gyro and Gyro Unfiltered for the plain Frequency spectrum; keep the two heatmap-mode defaults independent and preserve unavailable requested groups.
- Missing configured sources remain stored and visible but disabled across Graph/Table, Spectrum, Map, and fixed Step/Frequency Response options.

## Completed: About Acknowledgements and Community Access

- About includes an Acknowledgements action and an in-app detail thanking and linking to Betaflight, Betaflight Blackbox Log Viewer, Betaflight Configurator, and PIDtoolbox.
- The detail offers permanent free access to every Airframe feature for people who contribute public open-source work, software, videos, guides, documentation, blog posts, or comparable resources to the FPV community and routes requests through the existing feedback email.
- The community-access offer leads the detail content, and macOS exposes the same view through a dedicated Help-menu item and single reusable window.
- About and standalone Acknowledgements use borderless rounded windows with an opaque system-window backing, an in-content X close control, and no native titlebar strip. Both macOS Acknowledgements paths use the same exact 420 × 620 pt size and a fixed header followed by a separately clipped scrolling region.
- Project metadata, URLs, user-facing captions, accessibility identifiers, and the community promise have focused regression coverage.

## Live Acceptance Pending

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
