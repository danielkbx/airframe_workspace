# Current Plan

## Firmware Quaternion Craft Attitude (Completed 2026-08-03)

### Think Before Coding

- Prefer the flight controller's fused orientation only when all three logged quaternion fields exist and produce usable samples; preserve the established estimator as a deterministic fallback.
- Match Airframe's existing body-axis/world-frame signs exactly and keep CG reliability behavior unchanged.

### Simplicity First

- Reconstruct Betaflight's positive `w` from signed fixed-point x/y/z, normalize over-unit vectors exactly like upstream, and derive the orientation basis directly.
- Expose one `AnalysisAttitudeSource` enum while retaining source-compatible timeline initializers and derived availability booleans.

### Surgical Changes

- Limit production changes to `BlackboxAnalysis/Attitude`; quaternion fields remain hidden from the selectable series catalog and no Reader, UI, persistence, or document format changes are required.
- Decode quaternion instead of gyro/accelerometer when valid. Only a malformed complete quaternion pass incurs a second decode for gyro fallback.

### Goal-Driven Execution

- Added signed synthetic-log coverage for quaternion preference, quaternion-only logs, incomplete-triple fallback, coordinate signs, source provenance, positive-w reconstruction, and upstream-compatible normalization.

## Craft Attitude Loading Label (Completed 2026-08-03)

### Think Before Coding
- Use the otherwise unnecessary flight-mode position during quick loading; do not reintroduce the removed status-caption area.

### Simplicity First
- Replace the flight-mode chip during quick loading with plain localized `Reading … data…` text selected from the complete attitude, gyro, and accelerometer field triples already declared by the log.

### Surgical Changes
- Use one adaptive top `HStack`, remove the redundant manual layout chevron, swap the leading chip in place, and inset only the canvas rendering by 24 points while preserving its 210-point outer height.

### Goal-Driven Execution
- The active read basis is visible while it matters, the flight mode returns with usable preview data, the layout menu has one native chevron, and the controls do not visually collide with the craft.
- Verified all 214 `BlackboxAnalysis` tests and complete macOS and generic iOS Simulator app builds.

## Craft Preview Integrated Loading Indicator (Completed 2026-08-03)

### Think Before Coding

- Keep loading, usable quick data, full-log refinement, and terminal failure distinct. The visual loader exists only while both the cached result and quick timeline are absent.
- Preserve the preview's fixed 210-point geometry and all CG analysis, confidence, persistence, layout inference, and scrubbing behavior.

### Simplicity First

- `CraftSurfaceCanvas.ActivityState` is a two-case visual API with an `.idle` default. Only `.loading` creates a `TimelineView`; idle rendering remains event-driven.
- Loading uses deterministic one-second progress: quarter-ring motor-colored arcs follow each placement's direction, while a centered CG marker pulses. Reduce Motion renders the same indicators statically.

### Surgical Changes

- The expanded Graph Craft section removes all captions below the canvas and turns the top-right layout icon into a compact current-name menu with a chevron and accessible current value.
- `AirframeUI` owns rendering only; `Graph.CraftSection` derives the activity state from its existing quick/full timeline state. No analysis, persistence, document format, or external dependency changed.

### Goal-Driven Execution

- Added deterministic rotation, direction, normalization, and centered-CG tests plus loading/loaded SwiftUI previews.
- Verified all 127 `AirframeUI` tests and complete macOS and generic iOS Simulator app builds.

## Per-Log PID Tune Settings (Completed 2026-08-03)

### Think Before Coding

- Treat the selected Blackbox segment's own header as the only authoritative source. Never fall back to, merge with, or compare against an imported configuration because several flights in one source commonly use different PID settings.
- Present the settings that identify and materially influence the scored PID tune, not an unfiltered header dump. Keep filter configuration in Spectrum's existing dedicated surface.
- Preserve provenance explicitly: every displayed value must trace to a recognized header parameter in the currently selected log; absent values remain absent rather than being inferred from defaults, sliders, another segment, or firmware knowledge.
- Support header-name evolution through the existing canonical Reader header catalog and semantic aliases, including Betaflight 2026.6, while retaining older supported logs where their headers contain equivalent values.

### Simplicity First

- Add one sendable, read-only per-log PID tune settings projection in `BlackboxReader`, built solely from `DecodedLogHeaderInfo`.
- Group the presentation into `PID Gains`, `D Max`, `Feedforward`, and `Controller` values. Show P/I/D/F per Roll, Pitch, and Yaw first; include only additional logged values that materially affect PID behavior, such as D Max, TPA, I-Term Relax, anti-gravity, thrust linearization, and PID limits.
- Reuse canonical parsed header values and their raw source values. Do not parse an imported CLI dump, calculate effective defaults, reconstruct slider intent, or duplicate Spectrum's filter settings model.
- Expose availability as an optional projection so the UI omits the action when the selected log contains no useful tune settings.

### Surgical Changes

- Keep extraction and compatibility logic in `BlackboxReader`; keep labels, formatting, and the native popover in the Step Response/Frequency Response UI and `AirframeCaptions`.
- Add a compact icon-only `PID Settings` action to the far right of the Tune Score section header, following the existing Spectrum filter-settings affordance. The fixed header order is title, flexible space, score info button, then PID Settings button. The popover header contains only `PID Settings`; the per-log data binding establishes provenance without repeating the log name or explanatory copy.
- Reuse the same PID Settings popover from every Step Response log row. Place its primary-colored icon button immediately adjacent to the left of that row's visibility checkbox; both controls share one compact button group. A hidden trace still shows its title and PID Settings button in primary styling. The button must read `TraceSource.flightInfo.header` so document logs and attached reference logs always show their own recorded settings rather than the currently selected main log's settings.
- Use a table-like axis layout for P/I/D/F and established grouped data rows for the remaining settings. Give CLI/header names as help text where useful, support long values without awkward wrapping, and provide accessible labels.
- Make the popover follow the currently selected log. Switching logs closes or refreshes it deterministically; no settings choice is persisted in the document.
- Do not alter score calculation, Confidence, CHIRP analysis, document configuration resolution, or stored document format.

### Goal-Driven Execution

1. Inventory tune-relevant canonical headers across the supported Betaflight fixtures and the pinned 2026.6 source; define the exact allowlist and aliases before building UI.
2. Implement and unit-test the header-only projection with distinct settings in multiple segments, missing fields, legacy aliases, raw-value preservation, and an explicit test proving imported configuration data cannot enter the model.
3. Add one reusable PID Settings popover, expose it from the Tune Score section header, and add a per-trace icon immediately left of each Step Response visibility checkbox. Reuse Spectrum's visual conventions while presenting PID-specific groups and axis columns.
4. Test log switching and per-row presentation with different values, document and attached reference traces, no-settings omission, partial headers, long values, localization, accessibility, and both score and no-score states.
5. Run focused Reader/app/caption tests, macOS and generic iOS Simulator builds, String Catalog validation, visual screenshots, and diff review.

Success means a user can select any scored flight or inspect any Step Response trace and unambiguously recover the PID tune recorded for that exact segment, while no later imported configuration, currently selected log, or neighboring flight can contaminate the displayed values.

Implemented with a header-only `ReaderPIDTuneSettings` projection, modern and legacy axis-gain normalization, raw additional tune values, one shared native popover, Tune Score header access, and per-trace Step Response access for document and reference logs.

## Frequency Response Tune Score (Completed 2026-08-03)

### Think Before Coding

- Define the score as health of the PID tune observed in this one CHIRP log, never as PID optimality or proof that no better tune exists.
- Keep measurement confidence independent from tune quality. Poor evidence lowers confidence or suppresses the score; it never lowers the tune score itself.
- Score only dimensionless or defensible control-system properties. Do not reward absolute bandwidth because the desirable bandwidth depends on craft, filters, use case, and comparison data.
- Avoid double counting correlated evidence. Phase margin, peak sensitivity, closed-loop resonance, and derived step behavior contribute through named components with explicit ownership.
- Version the algorithm from its first release so later calibration can invalidate cached values and preserve interpretation.

### Simplicity First

- Add one pure `AnalysisFrequencyResponseTuneScoreCalculator` in `BlackboxAnalysis` returning a sendable result with overall score, rating, confidence, component scores, per-axis evidence, and explicit limitations.
- Derive the result from the already loaded `AnalysisFrequencyResponse.Result`; add only missing summary metrics such as peak sensitivity and reliable-frequency coverage.
- Use four user-facing components:
  - `Stability Margin`: reconstructed open-loop phase margin per axis.
  - `Robustness`: maximum sensitivity per axis relative to the +6 dB reference.
  - `Damping`: closed-loop resonant peak plus derived-step overshoot and settling behavior, combined without counting the same failure twice.
  - `Tracking Fidelity`: low-frequency closed-loop gain and normalized final step accuracy; bandwidth remains explanatory context, not a higher-is-better score input.
- Aggregate each component conservatively across axes as `60% weakest axis + 40% axis mean`. Aggregate components with a weighted geometric mean so one weak safety-relevant component cannot be hidden by several strong ones. Apply documented hard caps for clearly critical phase margin, sensitivity, or resonance.
- Present one decimal on a 1–10 scale and pair it with `Excellent`, `Good`, `Acceptable`, `Marginal`, or `Critical`; retain full precision internally.
- Compute Confidence from CHIRP completeness, reliable coherence coverage, usable frequency span, run count, and metric availability. Expose `High`, `Medium`, or `Low`; below the minimum evidence gate return `No Score` with reasons.

### Surgical Changes

- Limit domain changes to Frequency Response metric summaries, the new score calculator/model, and focused `BlackboxAnalysis` tests.
- Add a non-persisted `Tune Score` inspector section above `Axes`; the score always follows the selected log and loaded result.
- Render a compact circular 1–10 gauge with the numeric score centered, rating and Confidence adjacent or below, using stable dimensions and accessible text equivalents.
- List the four component rows below the gauge in the established data-row style. Each row shows component score plus concise measured evidence; an info button opens a native popover with formula, thresholds, per-axis facts, and any limiting condition.
- Put an info button in the section header. Its popover explains component aggregation, weakest-axis treatment, hard caps, Confidence, algorithm version, and the single-log/non-optimality limitation requested by the user.
- Do not make the section collapsible. Add all visible text through `AirframeCaptions`; add no persisted document setting or external dependency.

### Goal-Driven Execution

1. Specify and test piecewise scoring curves and safety caps before UI work. Boundary tests cover phase margin, sensitivity, resonance, step behavior, missing axes, non-finite values, and score range.
2. Test aggregation independently: weakest-axis weighting, geometric component combination, hard caps, deterministic ordering, and no-score evidence gates.
3. Test Confidence independently with complete/high-coherence, partial, legacy, incomplete, and insufficient-data inputs; verify Confidence never changes the tune score for identical valid metrics.
4. Calibrate labels and thresholds against synthetic transfer functions plus representative Stock/current/Wobble CHIRP logs. Record unresolved empirical thresholds instead of silently hard-coding unsupported precision.
5. Build the inspector section using existing score/data-row/info-popover patterns. Verify no empty section appears while loading or when no score can be explained.
6. Add accessibility labels for gauge, rating, Confidence, component rows, and info buttons. Verify macOS and iOS layouts, long localized text, Reduce Motion, and Dynamic Type.
7. Run focused analysis/app/caption tests, complete macOS and generic iOS Simulator builds, String Catalog validation, visual screenshots, and diff review.

Success means the same input deterministically produces an explainable score, every displayed number traces to concrete per-axis facts, insufficient evidence cannot masquerade as a poor tune, and the UI explicitly states that the result evaluates only this tune in this log.

Implemented with algorithm version 1, four independently explained components, conservative three-axis aggregation, weighted geometric overall scoring, hard safety caps, independent Confidence evidence, explicit no-score limitations, localized inspector presentation, and macOS/iOS verification.

## Individual Log Visibility (Completed 2026-08-01)

### Think Before Coding

- Persist stable source-hash/segment identities, never display names or ordinals, and keep at least one log visible even for malformed stored state.

### Simplicity First

- Filter one central presented-log projection and reuse the existing document state and macOS window-command broker.

### Surgical Changes

- Limit the feature to Airframe-document UI state, Sidebar context menus, View commands, captions, and focused tests; raw logs and payload bytes remain unchanged.

### Goal-Driven Execution

- Completed with persistent hide/show-all behavior, next-then-previous selection fallback, raw-log exclusion, 42 focused app tests, 29 caption tests, and green macOS/iOS Simulator builds.

## Regular-File Airframe Container

### Think Before Coding

- Preserve logical metadata v2 independently from physical container v1.
- Freeze legacy behavior before switching persistence; read-only open never migrates.
- Treat durable commit as the mandatory boundary before destructive FC/card cleanup.

### Simplicity First

- Keep all binary format, transaction, recovery, compaction, and export logic in `AirframeContainer`.
- Keep `AirframeWorkspaceDocument` as the visible value model and place one actor-backed adapter between it and platform document lifecycle.
- Use uncompressed immutable blobs, complete snapshot commits, APFS clone fast paths, and streaming fallbacks.

### Surgical Changes

- Land and verify package primitives, I/O, transactions, compaction, and export first.
- Add app manifest/codec and read-only dual-format opening before writable platform integration.
- Add opaque retention, first-mutation migration, then new-document and lifecycle paths.
- Preserve all unrelated dirty UI/test changes and make no public-repository commit without approval.

### Goal-Driven Execution

- Gate each milestone with focused tests and macOS/iOS builds.
- Completion requires invisible retryable migration, nonblocking saves, logical and physical deletion semantics, compact share/close snapshots, raw export, and video-ready range reads.

# Previous Plan (Completed 2026-07-30)

## Missing-Data Resilience

### Think Before Coding

- Treat stored graph field IDs and the main-frame time range as durable UI structure; data availability only controls whether a row or plot is active.

### Simplicity First

- Preserve missing graph rows with a local availability projection, and resolve the timeline through one deterministic source chain: Motor Average %, mean normalized Motor RPM, Setpoint Throttle, RC Command Throttle, or an empty time track.

### Surgical Changes

- Changes are confined to the Graph inspector projection, shared Timeline model/view, captions, and focused app tests. Public package APIs and persisted formats remain unchanged.

### Goal-Driven Execution

- Completed on 2026-07-30: missing Graph fields remain visible and disabled, and every log with a usable main-frame time range retains a scrub-capable Timeline with a clear fallback explanation.

## Previous Completed Plan

Move Map to the rightmost mode segment, leave macOS document window titles entirely to AppKit, and hide GPS-specific UI when the current log has no usable route.

## Think Before Coding

- Treat the segmented picker order as the source of truth for menu and numeric shortcut order.
- Set command routing to match the visible order: Spectrum `⌘4`, Step Response `⌘5`, Map `⌘6`.
- Never set a navigation or window title from document content on macOS; `NSDocument`/AppKit owns the filename and File Proxy.
- Set only the navigation subtitle, always to the selected log's effective name.
- Use one shared app-side GPS route usability gate for Map selection, command routing, fallback, and GPS Overview-card visibility.

## Simplicity First

- Reorder the existing `LogViewSelection` cases.
- Keep the menu shortcuts and event shortcut dispatcher aligned with `LogViewSelection.allCases`.
- Remove the redundant document-title propagation path.
- Reuse `LogContext.hasUsableGPSRoute` rather than duplicating route checks in each view.
- Add no new persisted state, captions, or window-management abstraction.

## Surgical Changes

- Touch only mode ordering, document-title propagation, GPS UI availability, the focused selection tests, and durable context.
- Do not alter playback, route rendering, inspector settings, or saved view state.

## Goal-Driven Execution

- Verify the mode order shows Map last and number shortcuts follow that same order.
- Verify the macOS document content has no title setter and its subtitle is exactly the selected log name.
- Verify no-route logs reject Map selection and do not show the GPS Overview card.
- Run focused app tests and a macOS build.

Implementation and automated verification are complete.

## Previous Shared Graph Event Chips Plan (Completed 2026-07-30)

Reuse Graph event-marker chips in Flight Map popovers.

## Think Before Coding

- Reuse the actual Graph chip renderer, not a visually similar reimplementation.
- Share the `ReaderEvent` to text/state content projection so Graph and Map cannot diverge.
- Keep Home information unchanged because it is not a Graph Event.

## Simplicity First

- Extract one public single-chip view from `GraphMarkerChips` and keep its styling in one place.
- Replace only the Map Event detail text with that shared chip.

## Surgical Changes

- Touch the reusable AirframeUI chip, the app Event-content projection, the Map popover, focused tests, and durable context.
- Do not change route/Event timing, map symbols, popover metadata rows, or captions.

## Goal-Driven Execution

- Verify Graph still renders through the extracted chip and Map builds the identical text/state content.
- Add focused content-projection tests, then run AirframeUI/app tests and macOS/iOS builds.

Implementation and automated verification are complete.

## Previous GPS Map Event Context Plan (Completed 2026-07-29)

Add semantic event context to Flight Map annotation popovers.

## Think Before Coding

- Resolve flight-mode bit changes with the same firmware-version-aware names used by Table and Graph.
- Resolve Inflight Adjustment function IDs and stored scaling through the existing centralized caption logic.
- Keep the short Event title distinct from its payload-derived detail.

## Simplicity First

- Add one optional semantic detail string to the existing annotation popover.
- Reuse `CaptionSet.flightModeChangeSummary` and `inflightAdjustmentCaption`; add no duplicate mode tables or scaling rules.

## Surgical Changes

- Limit production changes to the shared event-caption API and Flight Map popover wiring.
- Do not alter Reader events, Analysis markers, event reveal, route rendering, or persisted state.

## Goal-Driven Execution

- Add focused caption tests for Flight Mode and Inflight Adjustment context.
- Verify the Map passes firmware-specific flight-mode names and renders the optional detail.
- Run caption/app tests, macOS/iOS builds, diff review, and durable-context reconciliation.

Implementation and automated verification are complete.

## Previous GPS Map Annotation Plan (Completed 2026-07-29)

Add native annotation information and reduce Flight Map polyline rendering work.

## Think Before Coding

- Home information is contextual and selectable whenever Home is shown; Event information is selectable only after the progressive event reveal reaches it.
- Selection is transient and must clear when scrubbing/toggles remove the selected annotation.
- Reduce only display polyline geometry; current-position lookup, heading, event association, and Analysis data retain every prepared GPS point.

## Simplicity First

- Use SwiftUI `Button` plus an anchored native popover on the existing custom annotations.
- Show title, flight-relative time, coordinate, and available altitude without geocoding or a detail sheet.
- Bound the rendered polyline with deterministic sampling while always retaining its first and current endpoint.

## Surgical Changes

- Limit production changes to Flight Map presentation, two typed captions, focused tests, and durable context.
- Do not change Reader/Analysis retention, event semantics, Playback, camera persistence, or document state.

## Goal-Driven Execution

- Verify Home and revealed Events open one anchored info popover, hidden/future annotations cannot retain selection, and icon-only annotations remain accessible.
- Verify rendered route coordinates stay bounded and preserve first/current endpoints.
- Run focused app/caption tests, macOS/iOS builds, diff review, and durable-context reconciliation.

Implementation and automated verification are complete. Real-log visual feedback should confirm the native popover placement and perceived route smoothness.

## Previous GPS Map Refinement Plan (Completed 2026-07-29)

Refine the native Flight Map from real-log visual feedback.

## Think Before Coding

- Keep Map event reveal chronological, but show the complete prepared event set in the altitude timeline.
- Treat each recorded GPS point index as the visual identity of the route prefix and current-position annotation so MapKit receives prompt, bounded overlay updates.
- Anchor the heading cone at the position dot and make it widen in the recorded course direction.

## Simplicity First

- Keep the native SwiftUI Map, shared cursor, existing route projection, settings, and camera behavior.
- Remove only visible annotation titles; retain localized accessibility labels.
- Draw altitude grid labels as a small overlay using the same grid values already rendered by the profile.

## Surgical Changes

- Limit production changes to the Flight Map surface/profile and their focused documentation/tests.
- Do not change Reader/Analysis time association, playback cadence, Graph/Table timelines, or persisted settings.

## Goal-Driven Execution

- Verify the route polyline and position annotation receive a new identity at every recorded GPS point without recreating the Map camera.
- Verify the cone apex remains centered on the dot, Map labels are hidden, profile events ignore cursor time, and horizontal grid labels match their lines.
- Run focused tests, caption validation, complete macOS/iOS builds, diff review, and durable-context reconciliation.

Implementation and automated verification are complete. Real-log visual feedback should confirm the MapKit overlay refresh behavior and final cone appearance.

## Previous GPS Map Plan (Completed 2026-07-29)

Complete and verify the GPS Overview card and native Flight Map implementation.

## Think Before Coding

- Associate each usable GPS coordinate with decoded G-frame time, falling back only to current Main-frame context.
- Treat coordinates and time as untrusted input; keep route/event visibility as pure cursor-derived projections.
- Preserve the shared playback cursor and existing Graph/Table ranges; Map always uses the full Main-frame range.

## Simplicity First

- Use native SwiftUI MapKit, recorded samples, and the existing timeline graph/playback primitives.
- Add no dependency, interpolation, live location, camera following, range editing, or Overview-cache migration.
- Keep missing heading, Home, or relative altitude optional without disabling an otherwise usable route.

## Surgical Changes

- Extend the one-pass Reader scan with bounded route/Home retention, then project it immutably in BlackboxAnalysis.
- Split GPS metrics from Flight presentation, add `.map` command/state integration, and persist only per-segment display settings.
- Add native route annotations and a timeline-styled altitude profile without changing Graph/Table behavior.

## Goal-Driven Execution

- Verify Reader retention/validation, Analysis binary searches and reversible event reveal, settings round trips, command routing, captions, accessibility, and both platform builds.
- Finish with package suites, focused app tests, complete macOS/iOS builds, scope review, and durable context.

Implementation and automated verification are complete. An interactive visual smoke check with a representative GPS log remains useful but is not required for the completed code/build gate.

## Previous Overview Configuration Plan

Correct Overview configuration semantics and expose controller loop frequencies.

## Previous Overview Card Reorganization Plan

Reorganize the Overview dashboard around pilot-facing Log, Flight, Power, controller, hardware, and configuration concerns.

## Think Before Coding

- Keep persisted Overview values semantic and derive GPS metrics from the existing one-pass decoded scan.
- Treat Hardware as a distinct concern from FC identity: Board and detected Gyro, Acc, Baro, and GPS move together.
- Define Average Speed only from valid recorded GPS-speed samples and Maximum Distance from valid recorded positions relative to the flight start position; missing GPS evidence omits the row.

## Simplicity First

- Present cards in this order: Log, Flight, Power, Flight Controller, Hardware, Blackbox, Configuration, then full-width Notes. Hardware is placed after Flight Controller because the requested order omitted the newly requested card.
- Remove Recovered Gaps, rename Log Gaps to Gaps, and use Start Voltage / End Voltage.
- Move existing values without duplicating them across cards.

## Surgical Changes

- Extend the flight snapshot only with the two missing GPS aggregates and bump the Overview calculation algorithm version.
- Add focused Hardware and Power card views using the existing reusable card and key/value components.
- Update only the required caption identities, localized catalogs, previews, tests, and durable context.

## Goal-Driven Execution

- Run Reader metrics, card composition, and captions through agents with exclusive ownership, then integrate centrally.
- Verify deterministic GPS calculations, optional-row omission, requested card ordering, equal adaptive sizing, caption coverage, focused package tests, and macOS/iOS builds.

## Previous Header Alignment Plan

Normalize the reusable Overview card header height.

## Think Before Coding

- The optional action currently raises only cards that contain it because its 44-point hit target becomes the HStack's intrinsic height.
- Preserve the accessible action target and Dynamic Type expansion.

## Simplicity First

- Give every card's primary header row the same 44-point minimum height.

## Surgical Changes

- Change only the shared header HStack; do not add invisible placeholder buttons or per-card offsets.

## Goal-Driven Execution

- Verify compilation and confirm that action and non-action cards share identical content start positions.

## Previous Overview Refinement Plan

Refine the Overview card headers and compact pilot-facing values.

## Think Before Coding

- Resolve Blackbox debug numbers through the firmware's semantic debug-mode catalog rather than presenting raw numeric configuration values.
- Keep removed rows in the domain snapshot when they may remain useful elsewhere; this change concerns compact Overview presentation.
- Fix header alignment once in the reusable card component so every card receives the same geometry.

## Simplicity First

- Omit Disarms from the Flight card.
- Present a known debug mode by name and retain an honest unknown fallback for future firmware values.
- Vertically center icon, title content, and optional `More…` button in one shared header row.

## Surgical Changes

- Change only the Flight card row composition, the reusable card header layout, debug-mode resolution, focused tests, and the Overview cache algorithm identity if derived output changes.
- Do not redesign card bodies, navigation, or recorded-data details.

## Goal-Driven Execution

- Delegate independent Reader and SwiftUI edits, integrate without overwriting existing uncommitted work, and verify focused package tests plus macOS/iOS builds.
- Confirm the supplied Betaflight 4.6 value `19` presents as `GYRO_RAW`, all known values resolve deterministically, and future unknown values remain understandable.

## Previous Overview Dashboard Plan

Implement the adaptive Overview dashboard with persistent derived data.

## Think Before Coding

- Reuse the existing one-pass Reader scan and immutable source hashes; never rescan solely for Overview presentation.
- Keep semantic Overview snapshots independent from localized UI strings and cache-envelope identity.
- Derive recorded Blackbox availability from frame definitions, not from configuration intent.
- Preserve raw logs as read-only; persist Overview snapshots and Notes only in writable Airframe documents.

## Simplicity First

- Use equal-width adaptive cards containing compact technical key/value tables.
- Keep explicit card-level `More…` actions separate from optional value-scoped row buttons.
- Show card structure while scan-backed values load.
- Implement Recorded Data and configuration-file details as auxiliary sheets, not new primary log modes.

## Surgical Changes

1. Add typed Reader Overview snapshots, Blackbox classification, and scan-backed pilot metrics.
2. Add bounded Betaflight `dump all` parsing and deterministic associated/older configuration selection.
3. Store versioned Overview cache envelopes in existing package index data.
4. Add reusable card, table, row, and action components.
5. Compose Log File, Flight Controller, Blackbox, Configuration, and Flight cards plus full-width Notes.
6. Add searchable Recorded Data detail and read-only configuration-file detail.
7. Transfer already calculated snapshots during raw-log conversion and explain the benefit in the conversion prompt.
8. Verify packages, document round trips, iOS/macOS builds, compact layouts, Dynamic Type, and accessibility.

## Goal-Driven Execution

- Run independent Reader, cache/config, UI, and captions work through agents with exclusive file ownership, then integrate centrally.
- Accept only typed, tested, bounded data paths; missing values remain unknown rather than guessed.
- Finish with green focused package tests, app tests, iOS/macOS builds, and durable `.agents/` updates.
- Add the future GPS flight map and Start Location action to the backlog without reserving speculative persisted fields.

## Completed Flight Controller Import Plan

The prior Flight Controller Import Assistant plan is retained below for historical context.

## Think Before Coding

- Keep `MSP` generic and independent of Betaflight, Blackbox, transports, documents, and UI.
- Log MSP/CLI communication metadata through `Logging` without recording payload or CLI contents.
- Keep Betaflight behavior and serial/BLE transports in `FlightController`.
- The assistant returns a file-backed `FlightControllerImportPayload`; it never decides whether to create or extend a document.
- The app-side materializer creates a new package now and exposes the same atomic append path for future imports into open documents.
- Preserve downloaded Blackbox bytes through the valid log segment and trim FlashFS tail bytes after a terminal log-end marker during materialization. Support onboard FlashFS only; do not imply MSP SD-card file access.
- `Delete Logs After Import` toggle is wired to `MSP_DATAFLASH_ERASE`. Toggle (and log download) is only enabled when the blackbox device is `.flash`; otherwise both are forced off and a hint text explains the constraint. Erase runs after successful document materialization, guarded by a confirmation alert.
- Use no new external dependency without explicit approval.

## Simplicity First

- Assistant flow: Prepare → Device → Connect → Content → Import.
- macOS discovery combines USB serial and BLE devices; iOS/iPadOS shows BLE only.
- Connection validates MSP API version, `BTFL` variant, firmware, board, build, and FlashFS summary.
- Selected operations are log download and/or CLI configuration snapshot.
- Report real byte progress for FlashFS and indeterminate progress for CLI dump.
- Store temporary outputs under one managed import directory until successful materialization or final cancellation.
- Airframe format version 2 stores ordered FC import snapshots and content-addressed config files while reading version 1 unchanged.

## Surgical Changes

1. Add matching feature branches, pin `betaflight-configurator/` as a read-only reference, and update durable context.
2. Add the generic `MSP` package with v1/v2 frames, streaming decode, checksums, request coordination, timeout, cancellation, and CLI framing.
3. Add `FlightController` domain types, transport protocol, Betaflight client, and discovery abstractions.
4. Add the native SwiftUI assistant shell, captions, previews, step state, and mock discovery.
5. Add macOS IOKit/POSIX USB serial transport and real handshake/content discovery.
6. Add bounded, resumable file-backed FlashFS download with progress and cleanup.
7. Add CLI dump and validated `blackbox_*` settings reads/writes.
8. Add reusable payload types and explicit temporary-directory ownership.
9. Add append-capable package format version 2 and one atomic `AirframeImportMaterializer` mutation used by create and append.
10. Connect `StartView` to native destination selection, package creation, opening, and cleanup.
11. Add CoreBluetooth transport and known SpeedyBee/Nordic UART profiles.
12. Complete the shared BLE flow on macOS and real iOS/iPadOS devices.

Do not start a later item before the user approves the preceding commit. Do not add the open-document import UI yet.

## Goal-Driven Execution

- Each package milestone runs focused Swift Testing suites.
- App milestones build for macOS and iOS and add focused app/UI tests where platform behavior requires XCTest.
- Protocol tests cover fragmented/coalesced frames, checksums, malformed input, timeout, retry, and cancellation.
- Transport tests cover partial I/O, disconnect, reconnect, and BLE write chunking.
- Import tests cover logs-only, config-only, combined payloads, duplicate hashes, atomic append, version-1 compatibility, and temp cleanup.
- Hardware acceptance proves cable import on macOS and SpeedyBee Adapter 3 import on macOS and real iOS/iPadOS.
- A milestone is complete only when its behavior is verified, its diff is reviewed for scope, and its commit exists in the correct repository.
# Flight Controller Runtime Identity Capture

## Think Before Coding

- Capture runtime identity while Airframe already owns a live FC connection during import.
- Prefer the structured Betaflight `env` command and fall back to tolerant `status` parsing for older firmware.
- Keep stable identity/hardware facts separate from volatile import-time diagnostics and from configured state in `dump all`.
- Persist only a typed semantic snapshot; do not store the raw CLI response.

## Simplicity First

- Use one optional semantic snapshot shared by the import payload, document import record, assistant summary, and Overview precedence.
- Start with useful stable facts: firmware/build identity, target/board/manufacturer, exact MCU and clock, configuration state/size, detected hardware, and flash geometry.
- The assistant shows only concise general FC facts; sensor-chip detail remains in Overview.
- Unsupported or missing fields stay absent and never block log import.

## Surgical Changes

- Extend the existing CLI capture path rather than adding a second connection lifecycle.
- Add focused parsers for `env` and `status`, typed transport APIs, backward-compatible optional document fields, and narrow UI rows.
- Preserve current framed/interactive recovery behavior and all existing import modes.
- Increment Overview cache semantics when runtime identity begins taking precedence over inferred values.

## Goal-Driven Execution

- Verify structured parsing, fallback behavior, old-firmware absence, semantic Codable compatibility, payload/document round trips, assistant presentation, and Overview precedence.
- Run FlightController and format package tests, focused app tests, and complete iOS/macOS builds.
- Record stable protocol/version findings in `.agents/RESEARCH.md` and keep deferred diagnostic presentation in `.agents/BACKLOG.md`.
# Overview Information Hierarchy Refinement

## Think Before Coding

- Distinguish concrete detected GPS model names from configured providers; only the former belongs in the FC hardware row.
- Prefer one meaningful idle mode and remove rows that do not help a pilot scan the Overview.
- Keep persisted domain data intact when a value is merely removed from compact presentation.

## Simplicity First

- Assistant connected summary shows Board, Firmware, Processor, and Blackbox storage; Clock and Configuration State remain semantic data but are not displayed there.
- Configuration shows Dynamic Idle when nonzero, otherwise Motor Idle when nonzero; PID summary and GPS Provider are omitted.
- Flight shows Maximum Altitude only and omits Motor RPM.
- `More…` uses one native prominent card action aligned with the card title.

## Surgical Changes

- Change presentation and captions without removing reusable domain fields.
- Parse GPS runtime status into only concise module generations such as `M10`; unknown or provider-only values remain model-less.
- Bump the Overview algorithm version because cached GPS presentation semantics changed.

## Goal-Driven Execution

- Verify GPS parsing, idle selection, row omission, caption copy, button accessibility/alignment, and complete iOS/macOS compilation.
- Run FlightController, BlackboxReader, and AirframeCaptions tests plus focused app tests where applicable.
