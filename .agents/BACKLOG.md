# Backlog

Use this file to capture ideas, possible features, research leads, cleanup tasks, and future improvements without committing to implementation.

## Rules

- Add ideas here when they are worth preserving but not part of the current task.
- Keep entries short and concrete.
- Do not treat backlog entries as approved scope.
- Promote an entry to `TASKS.md` or a concrete plan only when the user chooses to work on it.
- Keep all entries in English.

## Parking Lot

- When an approved real motor anomaly/desync log is available, anonymize it (remove craft/pilot/GPS and unrelated headers), retain required motor/eRPM frames, document expected motor/time intervals, and add it as a public end-to-end regression fixture.

- Consider an optimized internal or persisted log representation after profiling parsing, seeking, memory use, and app startup behavior.
- Improve Airframe package autosave after profiling FileWrapper replacement costs for large main and reference logs; consider coordinated incremental package writes or native document subclasses if unchanged log payloads are repeatedly copied or uploaded.
- Investigate an upstream Betaflight firmware patch that enters USB MSC from a local button gesture, e.g. triple-press on a configured button while disarmed and storage-ready, reusing `systemResetToMsc(...)`; scope depends on target button availability and upstream UX/safety acceptance.
- Design bookmarks for important log positions before adding persistence. Define behavior, typed data, source/segment identity, editing, and navigation first; do not reserve speculative fields in the Airframe document format.
- Investigate whether `blackbox-tools` can provide reliable golden outputs for Swift parser tests.
- Investigate fixture sources for representative Betaflight logs across firmware versions, GPS usage, multiple flights, and corrupted/truncated logs.
- Evaluate whether `jcodemunch` indexing of `blackbox-log-viewer/` and `betaflight/` improves investigation speed.
- Add a macOS Quick Look extension that shows the most important summary data for a Blackbox log without opening the full app.
- Design and add the final Airframe app icon before App Store submission.
- Configure Apple Developer Team ID in Xcode signing settings once the team is identified.
- Build a native chart prototype that consumes `ReaderViewportResult` directly.
- Consider optional min/max envelopes for scan-overview samples if profiling shows stride sampling hides important spikes. Also reconsider overview retention only if its per-log memory cost becomes material.
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
- Presets: the current preset UI (sidebar `PresetList`, `PresetControls`, `PresetManager` sheet) is hidden as of 2026-07-23. The user was not happy with the overall UX. Redesign later. Code remains in place under `DocumentHome/Sidebar.swift` (`PresetList` struct) and `DocumentHome/Content/Presets/` so it can be re-enabled after the redesign.
- Let future named workspaces/presets own reusable document field-selection ID sets.
- Add map view support for GPS-capable logs.
- Spectrum follow-ups (base implemented 2026-07-15 with Frequency, Freq vs Throttle, Freq vs RPM; the user wants the deferred views later):
  - Power Spectral Density curve view: Welch method, default 512-sample segments, 75% overlap, Hanning, dB scale with a -70 dB floor, plus a segment-length control in the inspector.
  - PSD vs Throttle and PSD vs RPM heatmaps with minPSD/maxPSD/lowLevelPSD clamping (upstream defaults -40/+10 dB, low-level filter).
  - PID Error vs Setpoint view (average absolute axisError per setpoint value, per detected axis).
  - Spectrum filter overlays: LPF/notch cutoff lines and the dynamic-LPF expo curve from header semantic values; the `overlays:` layer slot in `SpectrumSurfaceCanvas` and the `SpectrumOverlay` cases already exist. (RPM notch harmonic distribution curves implemented 2026-07-17; see MEMORY.)
  - RPM notch curve shape validated against PTB Pro on btfl_007 (2026-07-17): near-identical. User chose the PTB-style raw distribution; the min_hz clamp was removed from `AnalysisRPMNotch.curve` the same day (loop-rate ceiling clamp retained).
  - RPM notch overlays extended to both heatmap modes (2026-07-17): locus lines/curves; validate the throttle-locus mean-per-bin shape against PTB Pro on the Q700 log; consider median if outliers skew, and per-bin sample-count minimum if sparse bins look noisy.
  - Spectrum CSV import/export of frequency/PSD curves like upstream Exp/Imp.
  - Exact upstream `rcCommands[3]` throttle handling is already matched (minthrottle/maxthrottle mapping); revisit only if upstream changes.
- Add video sync and video export support. Reuse Graph playback's shared current-position master timeline, monotonic anchor semantics, and global rate; the video player should synchronize to that transport rather than own an independent UI timer.
- Add large-log performance work if profiling shows slow startup, seeking, memory pressure, or repeated viewport queries.
- Harden Graph/Timeline gap rendering against genuinely pathological damaged logs: coalesce visual gap spans, replace per-point `gaps.contains` segmentation with a sorted two-pointer pass, and apply the Graph gap-chip cap before building all visible chip models. The 2026-07-23 false-gap cadence fix removes the current real-log trigger; this remains defense in depth.
- Add `airframe frames` to dump selected decoded frames by marker, time range, and limit for low-level debugging.
- Add `airframe summary` as a compact one-line-per-log command for shell pipelines.
- Add `airframe stats` for simple min/max/average/count over selected fields and time windows.
- Add `airframe derived` for `BlackboxAnalysis` series such as motor aggregates, PID sums, and debug descriptors.
- Add `airframe dump-config` to print Reader and CLI budget/default configuration.
- Add value predicates such as `--where amperageLatest>20` after the field/time filter MVP is stable.
- Add aggregate query filters for threshold and window-based analysis.
- Upstream-style flight-mode flag diffs in event chips ("ANGLE ON|USER1 OFF"): plumb the firmware CLI mode names from the header config into the graph marker captions (CaptionSet.cliEventSummary already accepts them).
- Craft section follow-ups (base implemented 2026-07-20: collapsible Graph inspector section, pseudo-3D Canvas craft, rotor ring gauges, complementary-filter attitude in `BlackboxAnalysis/Attitude/`):
  - Yaw readout as a number or compass rose next to the craft (yaw is already computed, deliberately not rotating the model).
  - Validate automatic mixer-template inference against representative real bicopter, tricopter, Y4, V-tail, A-tail, Hex Plus/H, Y6, X8 Plus, and flat-octo logs. LOG00027 is the local X8 starting point.
  - Attitude as graphable derived series (`AnalysisDerivedSeriesKind.attitude*` are still catalog-gated stubs); would need the timeline exposed through the series catalog with proper presentation metadata.
  - Persist the attitude timeline across window/document reopen if the one-time pass on very long logs annoys (currently per-view-state cache, recomputed per window).
  - HIGH PRIORITY: Use the logged `imuQuaternion[0..2]` as the preferred attitude source in the Craft view, with the current gyro/acc complementary filter as fallback. Betaflight logs it under `CONDITION(ATTITUDE)` (blackbox.c) when the ATTITUDE field is enabled; it is the firmware's own fused orientation, so it is more accurate (absolute heading, no yaw drift, no accelerometer/tuning dependence) and cheaper (decode 3 int16 + reconstruct `w = sqrt(1 - x²-y²-z²)` + quaternion→basis, no per-frame integration). Mirrors upstream `computeAttitude` (quaternion preferred, gyro+acc fallback). Read it directly in `AnalysisAttitudeSampleSource`/`AnalysisCraftTimeline` (the reader still decodes it even though it is hidden from the field picker); set `attitudeAvailable` true even without usable accelerometer. int16 quantization (~1/32767) is negligible for display.
- Step Response follow-ups (base implemented 2026-07-18: PTB-style Wiener deconvolution in `BlackboxAnalysis/StepResponse`, stacked Roll/Pitch/Yaw view mode with cmd-5, sidebar trace list with stable colors/toggles/hover/PID tune, session-only reference logs):
  - Bookmark-based reference-log restore across relaunch (local-only security-scoped bookmarks; must NOT go into the iCloud-mirrored document-state entry).
  - Synthesize setpoint from `rcCommand` + rates for pre-BF-4 logs that lack `setpoint[]` fields.
  - High/low-rate split traces as separate legend entries (calculator already flags high-rate windows and supports rate-class filtering).
  - Hook the step response workspace/compute caches into the memory-pressure path (currently bounded LRUs only: 12 workspaces, 72 axis results per surface, sized for the main log plus `ReferenceLogStore.maximumReferenceLogs` = 8 references across 3 axes).
  - Optional PTB regression harness: feed the Damping `.BFL` set through `AnalysisStepResponseCalculator` and pin peak/latency; the 2026-07-18 manual comparison matched PTB Pro curve peaks within a few percent (050/070/090 roll: ours 1.294/1.196/1.095 vs PTB curves ~1.25/~1.17/~1.08, ordering identical). Our QC accepts fewer windows than PTB (n lower); PTB's latency definition is a configurable dropdown and not directly comparable to our fixed time-to-50%-of-steady-state.
  - Hover crosshair with time/value readout in the step response panes (spectrum-style pointer tracking was deferred in v1).
