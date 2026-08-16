# Backlog

- Add client-side search to `Inside Airframe` only when the guide corpus makes browsing insufficient; keep JSON as the content source and avoid a search service or CMS.
- Add a clearly marked “Nerdy Tech Stuff” Inside Airframe article that explains the document format without presenting it as a permanent interoperability specification. Cover container versions, blobs, hashes, commits, export, recovery, compaction, and security boundaries; make any stable byte-format or third-party implementation commitment only after a separate product decision.

Unapproved future ideas only. Promote an item to [TASKS.md](TASKS.md) or an approved section in [PLAN.md](PLAN.md) when the user selects it. Completed work belongs in Git, current behavior in `ARCHITECTURE.md`, stable decisions in `MEMORY.md`, and evidence in the Knowledge Base.

## Near-Term Cleanup

- Re-evaluate the fixed macOS Log inspector after a SwiftUI/AppKit update. Restore a resizable native inspector only if the exact large Airframe Spectrum + cached Frequency-vs-RPM heatmap reproduction remains stable; do not reintroduce the retired overlaying AppKit split.
- In a future Airframe version, remove `LegacyAirframeConverter.swift`, legacy fixtures, and compatibility/migration/isolation tests after testers have converted their files. Rename remaining package-era type names at the same time; keep the logical metadata identifier `com.kumkju.airframe.document`.
- Surface `AirframeContainer` recovery/locator issues in a user-visible diagnostic.
- Add a transient Flight Controller import diagnostics view for uptime, temperature, CPU load, voltage, I2C errors, and arming-disable flags. Do not persist these runtime values.

## Tuning and Log Workflows

- The approved, ordered roadmap for guides, Step Response evidence, Filter Review/Score, comparison, next-flight guidance, setup assistance, CHIRP PID assistance, and the separately gated future Filter Assistant lives in [PLAN.md](PLAN.md#tuning-interpretation-filter-score-and-assistance-roadmap-approved-2026-08-05). Do not duplicate its contracts here.
- Add flat internal log folders and user-defined tags inside Airframe documents.
- Add specialized views for purpose-built recordings, starting with a Hover Test view.
- Compare Airframe's time-domain Wiener Step Response with the Configurator's CHIRP-derived frequency-domain Step Response on the same complete modern CHIRP logs before exposing a second curve.

## Flight Controller Connectivity

### BLE FlashFS Throughput

- Keep the hardware-validated 400-byte Huffman-compressed path as the stable baseline (~3.2 KiB/s) until a replacement completes end to end.
- Add privacy-safe aggregate telemetry, a dataflash-specific timeout, bounded output-budget benchmarks from 400 through 4096 bytes, progress throttling, and same-offset adaptive fallback for timeout/checksum failures.
- Treat a zero-character compressed response as insufficient output budget, not end-of-log. Preserve confirmed bytes, cancellation cleanup, and resumable offsets.
- Compare against Configurator on the same hardware. Consider pipelining only after stop-and-wait optimization is exhausted.
- Reduce comprehensive configuration time on the constrained shared-`FFE1` Bluetooth layout without reintroducing large continuous CLI responses: map more bounded binary MSP payloads back to replayable settings and retain per-setting CLI only for uncovered values.

### Mass Storage and Wi-Fi

- Investigate whether the SpeedyBee Adapter 3's transparent TCP 4278 MSP bridge offers a useful alternative to BLE for configuration capture after Wi-Fi join and before the existing MSC prepare command. The resolved ABF0 BLE profile now uses canonical `dump all`; retain this idea only if TCP proves materially faster or more reliable.
- Validate Mass Storage import on physical iOS/iPadOS: deletion/flush semantics, external-volume presentation, flash replug over BLE, compact layout, and the deliberate absence of interactive legacy-BLE configuration capture.
- Investigate a reliable host-side signal that a USB cable is actually attached before offering Mass Storage from a Bluetooth connection.
- Give known import failures typed, actionable messages while retaining an honest generic fallback.
- Add a `Connecting to the adapter…` state during the SpeedyBee Wi-Fi session-establishment delay.
- Determine why Adapter 3 rebursts lose packet clusters although initial bursts do not. Use monitor-mode capture; interface capture already ruled out receive-buffer overflow and Wi-Fi power-save keepalives. The current deduplicating reburst path remains correct but slower.
- Investigate SpeedyBee F7 V3 storage reporting and Wi-Fi protocol before adding any board-specific behavior.
- Consider an upstream Betaflight disarmed local-button gesture for entering USB MSC only after target hardware and safety/UX feasibility are understood.

Detailed SpeedyBee protocol evidence remains in [SPEEDYBEE_REVERSE_ENGINEERING.md](../knowledge/SPEEDYBEE_REVERSE_ENGINEERING.md); general transport evidence remains in [Flight Controller Connectivity](../knowledge/FLIGHT_CONTROLLER_CONNECTIVITY.md).

## Analysis, Compatibility, and Security

- When an approved real motor anomaly/desync log is available, anonymize it, retain required motor/eRPM frames, document expected intervals, and add a public end-to-end fixture.
- Obtain representative fixtures across supported Betaflight versions, multiple flights, GPS, different mixer layouts, and damaged/truncated logs.
- Validate parser output against `blackbox_decode` or `blackbox-tools` goldens.
- Add optional coverage-guided parser/reader fuzzing with sanitizers, separate from normal `swift test`.
- Consider an optimized internal/persistent log representation only after profiling startup, seeking, autosave, and memory.
- Add large-log performance work only when profiling identifies a specific bottleneck.
- Harden Graph/Timeline gap rendering against pathological logs with coalesced spans and bounded chip construction.
- Consider scan-overview min/max envelopes only if profiling or fixtures show stride sampling hides material spikes.

## Analysis and Presentation Follow-Ups

- Post-1.0 only: implement the approved [Battery Sag Score plan](BATTERY_SAG_SCORE_PLAN.md). It adds one evidence-backed Good/Okay/Poor row to the existing Power card and explicitly does not estimate internal resistance or Battery Health.
- Add a conservative Heading Consistency health check that compares firmware-quaternion nose heading with GPS course only across sustained, sufficiently fast, low-yaw, low-roll forward-flight evidence. Use circular error statistics and require a stable material offset; missing, sparse, or unstable evidence must remain not assessable. Report a neutral `Heading disagreement`, not `Compass miscalibrated`, because wind, sideslip, reverse/sideways flight, GPS error, initialization, and non-magnetometer yaw fusion can also separate nose and course. A directly matching FC configuration with `trust_mag = ON` may raise confidence in a compass calibration/alignment interpretation but must not be required for the log-only discrepancy finding. Validate thresholds against representative correctly calibrated and deliberately miscalibrated real logs before implementation.

### Spectrum

- Add threshold-duration analysis and heatmap/spectrogram Y-intensity measurement only after separate interaction and semantics are approved; neither belongs to the current X-only measurement.
- Add Welch PSD frequency and PSD-vs-Throttle/RPM views after defining estimator compatibility, controls, dB normalization, and presentation metadata.
- Add PID Error vs Setpoint.
- Validate throttle-locus RPM-notch aggregation against PIDtoolbox Pro on the Q700 log; consider median or a minimum bin count only if evidence shows outlier/sparsity problems.
- Add Spectrum CSV import/export for compatible curves.

### Step Response

- Restore reference logs across relaunch with local security-scoped bookmarks; never mirror bookmarks through iCloud document-state storage.
- Synthesize setpoint from `rcCommand` plus recorded rates for older logs without `setpoint[]` only after versioned equivalence tests.
- Expose high/low-rate windows as separate trace choices.
- Integrate Step Response workspaces/results with the document memory-pressure path.
- Add a PIDtoolbox regression harness for peak/latency and document the estimator/latency-definition differences.
- Add a hover crosshair with time/value readout.

### Craft, Timeline, and Graph

- Add a yaw readout or compass rose without rotating the craft model.
- Validate mixer-template inference beyond Quad X and expose attitude as selectable derived series only after complete presentation metadata exists.
- Persist the attitude timeline only if long-log recomputation becomes a measured problem.
- Add a Timeline metric switcher and hover/drag time readout.
- Add the remaining preset management as a separate approved step: duplicate. Preserve the action-only semantics and compact generation-2 library; do not add active selection, dirty state, or automatic synchronization back from documents.
- Add remaining native chart interactions or aggregation only when the current Graph model lacks a concrete workflow.

### Map and Export

- Add optional GPX export through CLI and app.
- Consider speed/altitude route coloring, geocoding/search, terrain/3D, and richer event detail only as separate features.
- Add video synchronization/export on the shared Graph playback timeline rather than a separate transport clock.
- Add a macOS Quick Look extension for compact Blackbox summaries.

## CLI Follow-Ups

- Add a controlled Blackbox test-log generator CLI that configures `MOTOR_TEST`, starts and stops recording cleanly, waits for Blackbox shutdown, restores `NORMAL`, and optionally verifies the resulting log. Explicitly avoid the `ALWAYS` save/reboot race.
- Add `airframe frames`, `summary`, `stats`, `derived`, and `dump-config` commands.
- Add value predicates and aggregate window filters only after the basic field/time query model is stable.

## Deferred Data and UX Ideas

- Resume iPadOS readiness only after a new explicit approval. Deferred acceptance includes the full `IPAD_AUDIT.md` window/orientation matrix; VoiceOver, largest Dynamic Type, hardware-keyboard, Reduce Motion, and multi-touch checks; Recent Documents validation across On My iPad, iCloud Drive, and a third-party provider; close/background lifecycle checks; and representative long-log Graph/Spectrum profiling.
- Add or restore iPhone support only as a separately approved product effort. It requires its own compact-width design, implementation, and acceptance work; do not re-add device family `1` as incidental shared-platform maintenance.

- Design persistent bookmarks for important log positions before reserving document fields.
- Add upstream-style flight-mode flag diffs to event chips using firmware-specific mode names.
- Add a Start Location action that opens Map and focuses the coordinate.
- Add further raw/derived series, units, grouping, and picker metadata only through the established Series Presentation Rule.
