# Backlog

Use this file to capture ideas, possible features, research leads, cleanup tasks, and future improvements without committing to implementation.

## Rules

- Add ideas here when they are worth preserving but not part of the current task.
- Keep entries short and concrete.
- Do not treat backlog entries as approved scope.
- Promote an entry to `TASKS.md` or a concrete plan only when the user chooses to work on it.
- Keep all entries in English.

## Parking Lot

- Consider an optimized internal or persisted log representation after profiling parsing, seeking, memory use, and app startup behavior.
- Consider an Airframe-owned document format that stores app metadata, view settings, analysis state, and the original unmodified log bytes so the raw log can be exported again.
- Add bookmarks for important log positions that users can jump back to quickly; this likely depends on an Airframe-owned document format for persistence.
- Investigate whether `blackbox-tools` can provide reliable golden outputs for Swift parser tests.
- Investigate fixture sources for representative Betaflight logs across firmware versions, GPS usage, multiple flights, and corrupted/truncated logs.
- Evaluate whether `jcodemunch` indexing of `blackbox-log-viewer/` and `betaflight/` improves investigation speed.
- Add a macOS Quick Look extension that shows the most important summary data for a Blackbox log without opening the full app.
- Design and add the final Airframe app icon before App Store submission.
- Configure Apple Developer Team ID in Xcode signing settings once the team is identified.
- Build a native chart prototype that consumes `ReaderViewportResult` directly.
- Done 2026-07-13: one-pass timeline data via `ReaderScanOverview` (see TASKS). Remaining overview follow-ups: optional min/max envelope per retained sample (stride sampling drops sub-stride spikes), display-scaled overview projections when a consumer needs units, dropping the overview from retention if per-log memory (~1 MB) ever bites on 128-log documents.
- Timeline metric switcher (max RC deflection / motor differential styles) as alternative Y signals.
- Optional per-chunk min/max pre-aggregation per series for Graph intermediate zoom levels, only if profiling shows on-the-fly decimation of cached chunks is too slow (2026-07-13: deliberately deferred; overview covers wide zoom, chunk cache covers detail zoom).
- Table view consumer: select the row nearest to the shared current-position time; Graph view consumer: center the traces on it.
- Timeline hover/drag readout showing the position time and a scrub preview.
- Add native chart interaction: pan, zoom, scrub cursor, legends, value inspection, and series visibility.
- Expand compatibility coverage across more Betaflight versions and representative real logs.
- Validate parser output against `blackbox_decode` / `blackbox-tools` golden data.
- Add an optional coverage-guided fuzzing setup for parser/reader security, likely starting with a libFuzzer harness plus sanitizers, separate from normal `swift test`.
- Add derived fields such as PID sums, setpoint/RC command presentation, motor aggregates, GPS cartesian coordinates, distance, azimuth, trajectory tilt, and attitude estimates.
- Add a CLI command that converts GPS data from Blackbox logs into an exportable GPX file.
- Add app support for exporting GPS data from loaded logs as GPX files.
- Add units and presentation metadata for raw and derived fields, including scaling, labels, display precision, and axis hints.
- Add field grouping and picker metadata for common tuning workflows without copying upstream graph configuration architecture.
- Add workspace or graph preset support after the native chart model is proven.
- Let future named workspaces/presets own reusable document field-selection ID sets.
- Add map view support for GPS-capable logs.
- Add spectrum analyzer / FFT analysis.
- Add video sync and video export support.
- Add large-log performance work if profiling shows slow startup, seeking, memory pressure, or repeated viewport queries.
- Add `airframe frames` to dump selected decoded frames by marker, time range, and limit for low-level debugging.
- Add `airframe summary` as a compact one-line-per-log command for shell pipelines.
- Add `airframe stats` for simple min/max/average/count over selected fields and time windows.
- Add `airframe derived` for `BlackboxAnalysis` series such as motor aggregates, PID sums, and debug descriptors.
- Add `airframe dump-config` to print Reader and CLI budget/default configuration.
- Add value predicates such as `--where amperageLatest>20` after the field/time filter MVP is stable.
- Add aggregate query filters for threshold and window-based analysis.
- Upstream-style flight-mode flag diffs in event chips ("ANGLE ON|USER1 OFF"): plumb the firmware CLI mode names from the header config into the graph marker captions (CaptionSet.cliEventSummary already accepts them).
