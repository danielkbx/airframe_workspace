# Active Tasks

Only approved near-term work and unresolved acceptance gates belong here. Completed work belongs in Git and the current architecture; unapproved ideas belong in [BACKLOG.md](BACKLOG.md).

## Implemented, Live Acceptance Pending: X-Range Measurement

- The approved 1.0 exception replaces Spectrum snapping with persistent X-range selection on Graph, Spectrum, Step Response, Frequency Response, and spectrogram/heatmap modes.
- Exact Graph statistics stream through indexed Reader chunks; prepared analysis curves use the same extrema/statistics reducer. Time curves expose conservative per-series oscillation estimates, including multiple-period averaging and typed rejection.
- Automated package, state, macOS, and iOS build gates pass. Remaining acceptance is a live Option-drag/iPad ruler pass plus long-log profiling that confirms no decode during drag and no static-canvas invalidation from pointer updates.
- The 2026-08-07 source-level SwiftUI performance remediation localizes and deduplicates the draft in the overlay leaf, coalesces visible pointer updates to at most 120 Hz, computes pane domains outside that leaf, formats the chip once with a retained formatter, replaces the chart-sized overlay `Canvas` with bounded rectangles, and hides surface calculation handles behind stable non-observable owners. Automated state/package tests and platform builds cover the structural fix; the remaining live Instruments pass must confirm no decoding during drag, no static-canvas invalidation from pointer updates, and prompt release after repeated open/measure/close cycles.

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

### Step Response Horizontal Zoom

- On iPad hardware, verify touch-anchored pinch, two-finger pan, double-tap reset, the existing one-finger range measurement, VoiceOver adjustment, and hardware-keyboard Zoom commands at 1x...10x.
- On macOS, verify trackpad pinch, trackpad/mouse-wheel pan, double-click reset, range measurement, and View-menu Zoom commands.
- Profile a representative multi-log overlay while continuously zooming and panning. Analysis must not restart, static work must remain visible-sample bounded, and document persistence must publish only at interaction boundaries.
- Manually verify the full-height vertical crosshair and attached time chip across the full and zoomed viewports on iPadOS and macOS, including coexistence with the armed range-measurement gesture.

### iPad Readiness And Canvas Touch Pass

- Run the portrait/landscape and narrow/intermediate/wide window matrix in [IPAD_AUDIT.md](IPAD_AUDIT.md), including long document names and expanded/collapsed Timeline states.
- Complete the VoiceOver, largest Dynamic Type, hardware-keyboard, Reduce Motion, and physical-device multi-touch checks documented in the audit.
- Validate document close/background behavior with iCloud Drive and a third-party document provider, and profile aggressive Graph/Spectrum gestures with representative long logs.
- Treat visual marker collision tuning and any findings from these gates as bounded follow-up work; do not expand the 1.0 feature set.

### T-Motor FFE0 Bluetooth UART

- Root cause identified 2026-08-06 with the standalone probe `tools/tmotor_ble_probe.swift` (FCC-010): `FFE1` carries raw MSP with no activation or extra framing, and the board is confirmed as `TMOTORVELOXF7SE` (Betaflight 4.5.4, API 1.46) from BOARD_INFO. 10 of 10 probe sessions completed the full identity handshake, DATAFLASH_SUMMARY, and a 512-byte DATAFLASH_READ. The only fragility is the first MSP request directly after notify enable, which can be answered ~1.6 s late or dropped; a ~500 ms pre-write delay or one retry fixes every session. The Android capture idea is obsolete.
- Airframe now retries the idempotent first `MSP_API_VERSION` request once after timeout; package tests cover a dropped first response and exhaustion after the single retry. Live Airframe completed identity, dataflash summary, the full 38,912-byte Direct download, regular-document save, and reopen. Independent compressed, uncompressed, and Mass Storage reads prove the malformed headers were already damaged on FlashFS. Two concrete 128-byte insertion forms have now been captured inside `Field I name`: three consecutive copies of one 64-byte range, and a later mixed stale-byte insertion that produced 51 names for 37 definitions. The reader repairs the first exact pattern directly; for the second it removes exactly 128 bytes only when every splice search yields one unique, structurally plausible, normally interpretable main-frame schema. Both preserve original bytes and record a warning. Every FC import path (Direct, Mass Storage, and Wi-Fi) requires each copied log to contain a readable Blackbox segment before returning a payload. A repaired import succeeds with a concise warning, remains deletable only after a second confirmation, and appears as `Repaired` in the Checks `Log Quality` row; the former bottom Overview Issues section is removed. An unrecoverable import stops before deletion with a specific message saying the FC data was not deleted. Zero-readable-log failures also surface as a clear localized document error for raw logs and embedded `.airframe` sources. The tested T-Motor shared-`FFE1` Bluetooth layout has a verified streaming limit: framed `dump profile` disconnects after 1,018 response bytes, while bounded exact `get` requests remain stable. Comprehensive segmented capture supports that constrained layout across BF 4.3, 4.4, 4.5, 2025.12, and 2026.6. The resolved post-connect BLE profile now selects capture: shared `FFE1` stays segmented, while SpeedyBee V2 and all other recognized profiles use `dump all`; unknown capability remains conservative. The same capability enables CLI `env/status` only on recognized nonconstrained Bluetooth profiles. Direct, Wi-Fi, and Mass Storage share this decision. Package and focused app runtime tests pass; live profile-based acceptance remains to be rerun.
- Profile-selected capture is live-confirmed for a 38,340-byte USB Direct complete dump and a 35,023-byte SpeedyBee V2 Mass Storage complete dump. The original 8 MiB `LOG00001.BFL` on `STITCH` contained four Blackbox start markers: three readable logs and one header truncated at the 1 MiB boundary. The Reader now skips only that malformed candidate, retains the three readable logs and their original segment indices, reports partial recovery, and requires a second confirmation before deletion. Core, Reader, Caption, FlightController, and focused app runtime tests pass; the original mounted file is verified as three readable logs plus one source issue.
- Zero-readable-log FC imports now state that the Blackbox log is damaged and cannot be imported, confirm that nothing was deleted, and never suggest retrying another transfer method. Caption coverage locks this distinction from generic retryable import failures.
- The connection/action combination cleanup is complete without behavior changes: one connection-flow matrix owns source/config/status/dataflash policy, one controller-capability model owns offered methods/options, one post-import deletion flow owns cleanup selection, and Direct/Wi-Fi share payload lifecycle code. The full macOS run passes 727 app tests plus 6 UI tests with one known runner skip; FlightController passes 168 package tests.
- Direct overall progress now weights segmented configuration at the existing leading 15%, complete dump at a small trailing 2%, and no-configuration imports at 0%; targeted runtime/state coverage passes 78 tests and verifies monotonic 0–100% ranges. The complete T-Motor Bluetooth support and associated import/recovery work is committed in public Airframe commit `d5b4dd9`.
- Fix the current capability mismatch where Wi-Fi mode offers `Delete Logs After Import` although no Wi-Fi erase operation exists. The immediate safe behavior is to disable/reset the option in Wi-Fi mode; a future reconnect-and-erase flow is separate scope and requires hardware validation.
- SpeedyBee Adapter 3 Direct profiling confirms configuration capture is latency-bound: roughly 1,089 serialized requests took about 82 seconds for 37,612 bytes, while the subsequent 360,448-byte compressed log transfer took 50 seconds. Reduce bounded request count rather than raising BLE byte limits; live validation should compare request count, configuration completeness/restorability, and elapsed time.
- New imports persist per-log origin as File, USB, or Bluetooth and show it in the Log Overview card. The value represents initial controller contact, so Bluetooth remains correct for Direct, Wi-Fi, and Mass Storage initiated over BLE. Segmented configuration format 2 is directly replayable for all captured catalog settings and profiles using Betaflight batch validation plus `save`.
- Root-cause evidence for the repaired 128-byte FlashFS headers now points to the Betaflight `blackbox_mode = ALWAYS` save/reboot workflow rather than Airframe transfer: the same damage reproduced on two FCs before Airframe started, upstream starts logging immediately after the mutable mode changes to ALWAYS, NORMAL does not stop that test-mode session, and reboot paths do not finish Blackbox. FlashFS's async ring buffer is exactly 128 bytes. No additional Airframe implementation is approved from this finding; retain the safe reader recovery and use `MOTOR_TEST` for future controlled FC-only test logs.
- Complete structural restoration from segmented Bluetooth captures remains approved follow-up scope. Build version-specific Airframe restore mappings for the retained MSP records. Do not claim exact restoration of resource/timer/DMA assignments unless Betaflight gains a bounded getter or another hardware-safe capture method is proven.
- `AE00/AE01/AE02` matches the module's separate JieLi OTA channel and remains excluded from MSP profiles. `FFE0` also exposes undocumented `FF02`/`FF03` characteristics; ignore them for MSP.

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
- Live-profile the 2026-08-07 Spectrum interaction fix with a representative large log: zoom deeply, pan by drag/trackpad/wheel, resize the window, and confirm no `exportedPackageState`, `updateMetadata`, FFT, or semantic preparation appears during direct manipulation. Confirm one state publication after the interaction boundary or one-second quiet period.
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

## Airframe 1.0 Release Gate

- Implement the Paywall shortly before the 1.0 release. Preserve the permanent community-access entitlement recorded in `MEMORY.md`.

## Current Constraints

- Airframe 1.0 is under feature freeze until further notice; its functional scope is fixed apart from the approved pre-release Paywall.
- Current product work targets iPad/iPadOS. When the user does not name a platform, interpret the request as iPad/iPadOS until explicitly changed.
- Preserve macOS behavior and presentation unless the user explicitly requests macOS work. Isolate required platform differences with conditional compilation for small changes and platform-specific files for changes longer than a few lines. Prefer separate macOS and iOS/iPadOS SwiftUI view implementations when a view has substantial platform-specific structure.
- New product work remains planning-only until the user selects a measure from [PLAN.md](PLAN.md) or a backlog item.
- No new external dependency without explicit approval.
- Raw Betaflight logs remain byte-identical and read-only.
- Airframe document state belongs in document metadata; raw-log UI state remains external.
- Bookmarks are not part of document format version 1.
