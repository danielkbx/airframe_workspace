# Current Plan

## Betaflight 2026.6.1 and Blackbox Explorer Reference Refresh (Implemented 2026-08-05)

### Think Before Coding

- Separate the stable 2026.6.1 tag, the maintenance branch, and 2026.12-alpha master before assigning compatibility meaning. Treat the MSP box list and the 32-bit Blackbox flight-mode payload as different contracts.

### Simplicity First

- Advance the read-only BF/BE references and recognize only the new logged header `ap_position_f`. Keep MSP API 1.48, Blackbox Data version 2, frame decoding, and the logged flight-mode catalog unchanged.

### Surgical Changes

- BF now references tag 2026.6.1 and BE current master. Airframe recognizes `ap_position_f`, cites the final 2026.6 debug enum, and explicitly leaves `WP CAPTURE` out because its late box bit is not serialized by Blackbox. BE's intervening changes are workflow/lockfile-only.

### Goal-Driven Execution

- Focused Reader tests prove the new header is typed and known while 2026.12-alpha debug value 102 remains unknown under the stable catalog. A representative real 2026.6.1 log remains follow-up evidence.

## Inspector Scroll and Hover Stability (Implemented 2026-08-05)

### Think Before Coding

- Hover-driven Graph, Spectrum, Frequency Response, and Step Response highlights are transient window state. Delay activation centrally in the shared highlight states, not in individual inspector rows; keep exit, explicit clear, and tap toggles immediate.

### Simplicity First

- Use one small app-internal `DebouncedHover<Value>` helper with a fixed 500 ms activation delay, making highlight an intentional dwell interaction. Spectrum keeps independent helpers for its seven independently valid highlight channels. No setting, persistence, dependency, or AppKit bridge is added.

### Surgical Changes

- Graph, Table, Spectrum, and Step Response inspector Forms hide only their vertical scroll indicators. Inactive Spectrum filters/groups, hidden Step/Frequency traces and axes, and hidden response/spectrogram guides never publish hover highlights. Scrollable popovers and unrelated toolbar/reorder hover styling remain unchanged.

### Goal-Driven Execution

- Eight focused tests cover delayed activation, early exit, target replacement, repeated active events, immediate tap toggles, explicit clear, independent Spectrum channels, and Step Response behavior. Fresh macOS and generic iOS Simulator Beta builds pass; live macOS scroll/checkbox acceptance remains.

## Graph Playback and Scrubbing Presentation Cadence (Implemented and Live-Profiled 2026-08-05)

Live acceptance on `Tuning.airframe` is complete for the scoped performance work. The user reports that playback and aggressive scrubbing feel “very, very much better” and close to ideal. Final traces contain no per-cursor SHA-256/log-source replacement, no Graph prepared-series persistence during scrubbing, and no raw `Graph.loadPoints` work during the final covered scrub. Remaining CPU is predominantly SwiftUI/AppKit layout and Core Animation presentation while the Graph now delivers substantially more visible frames instead of blocking behind document hashing. Persistent Graph bundle restore/encode amplification remains a separate follow-up candidate, not approved scope for this pass.

### Think Before Coding

- Keep `DocumentStateStore`'s current position as the exact authoritative cursor. Playback timing, Graph window selection, direct manipulation, In/Out actions, keyboard stepping, persistence, and final pause/seek state must never use a delayed presentation value.
- Treat cursor consumers by perceptual and semantic need instead of making every consumer either frame-rate or static. The moving Graph plot needs the exact position at the current transport/gesture cadence; secondary motion may be sampled; text, inspector values, accessibility summaries, and command enablement may update more slowly.
- Preserve immediate correctness at boundaries. Log changes, discrete clicks/keyboard steps, playback start/pause/end, scrub end, range changes, and view changes must force all presentation channels to the exact current position rather than waiting for the next cadence interval.
- Do not classify the disappearing-line symptom as UI-only. The controlled scrub trace contained real `Graph.loadPoints`/Reader viewport work after a preceding playback, so UI cadence, cache persistence contention, prepared coverage, render-ready coverage, and display fallback require separate evidence and acceptance gates.
- Use the controlled 2026-08-05 traces as the baseline: idle 0.0-0.2% CPU; warm playback 10,525/11,581 sampled CPU milliseconds on the main thread with no Graph loads or cache writes; aggressive scrub with 904 `Graph.loadPoints` samples, 1,140 prepared-series encoding/store samples, and only 40 `drawSeries` samples.

### Simplicity First

- Extend the existing window-scoped `LogPlaybackController` with presentation snapshots rather than adding per-view timers, display links, Combine publishers, or another document owner. The existing playback tick and direct-manipulation callbacks already observe every exact position change and can rate-limit publication using `ContinuousClock` without losing the exact stored cursor.
- Publish two identity-bound presentation channels as a starting policy, with exact values forced at semantic boundaries:

  | Consumer class | Starting cadence | Examples |
  | --- | ---: | --- |
  | Exact motion | Existing transport/gesture cadence, nominally 60 Hz | Graph visible range, traces, Graph cursor, cache/load decisions |
  | Secondary motion | At most 30 Hz | Timeline cursor, craft attitude and motor gauges |
  | Readout/status | At most 10 Hz | Timestamp text, Graph field values, flight-mode chip, command enablement, accessibility position text |

- Make cadence thresholds internal policy constants with pure tests. Adjust them only from live evidence; do not expose user settings or build a general scheduling framework.
- Keep one authoritative write path per user action. The presentation controller receives the exact value after that write; it never writes a sampled value back into `DocumentStateStore`.
- Reuse the prepared-cache actor's existing overlapping suspension semantics. Direct Graph interaction should hold its own suspension token so playback, frontier construction, and scrubbing can overlap without one caller accidentally resuming persistence while another is still active.

### Surgical Changes

1. Add identity-bound `secondaryPosition` and `readoutPosition` presentation state to `LogPlaybackController`, plus a small API that records an exact position as continuous or forced. Playback ticks publish through it; Graph/Timeline gestures and discrete cursor commands publish after their exact state-store write. Seed or clear the channels on log/view configuration changes, pause, and shutdown so no log can display another log's sampled position.
2. Keep `Graph.CursorWindowLayer`, load-window hysteresis, coverage-loss detection, and urgent cache decisions on the exact state-store cursor. Do not throttle or quantize the graph itself in this phase, and do not replace the 16 ms playback task with a display link until the invalidation reduction is measured.
3. Split the exact transient Graph visible range from the externally published/persisted visible range. `CursorWindowLayer` may move its exact projection every tick, and `updateLoadRequest`/overview fallback must react immediately when hysteresis or coverage boundaries are crossed. However, `stateStore.setGraphVisibleRange` must publish at the secondary cadence and force the exact final range on pause, scrub end, zoom end, range/log change, and disappearance. Timeline overlay and command enablement consume only that sampled publication. This removes the current per-tick `graphVisibleRanges` mutation that invalidates consumers outside the Graph canvas.
4. Move the changing timestamp out of the parent `LogTimelineToolbar`/`LogPlaybackControls` input graph. A small timestamp leaf reads the 10 Hz presentation position inside a fixed-width slot; the play button, speed slider, dividers, labels, and capsule remain structurally and layout stable while the time changes.
5. Make `LogTimeline` consume the 30 Hz presentation position for its cursor line and accessibility value while its drag gesture continues writing exact positions. Keep range overlays, markers, graph-cache coverage, and the static area graph independent from cursor sampling.
6. Make `Graph.CraftSection` render the cached timeline's attitude and motor gauges from the 30 Hz channel, while prepared-series exact motor readouts and flight-mode/status text use the 10 Hz channel. Preserve the existing stale-while-revalidate behavior; remove the redundant local 80 ms throttle only after the shared cadence tests prove no query-rate regression.
7. Make `GraphSetupEditor` key numeric readout work from the 10 Hz presentation position, not the exact `logPositions` dictionary. The field list, section controls, hover state, and layout must not observe exact cursor mutations.
8. Remove exact cursor and exact `graphVisibleRanges` reads from `LogDataView.commandState`. Compute previous/next-interesting-time and zoom enablement from the 10 Hz presentation snapshot, but have each action re-read exact cursor/viewport state when invoked. Other command capabilities remain semantic-only. This is the primary boundary expected to stop Focused Values, the toolbar hierarchy, and unrelated Sidebar/navigation content from joining every playback transaction.
9. Audit every remaining `currentPositionTime` and `graphVisibleRange` reader in the Graph window and assign it explicitly to exact, 30 Hz, 10 Hz, or discrete-only behavior. A source test should reject new unclassified exact cursor/viewport reads in Graph inspector/toolbar/menu files while allowing the Graph surface, load policy, and action handlers.
10. Hold Graph prepared-series persistence suspended from the first direct interaction event through the post-interaction quiet/refinement boundary. Cancel a pending release when interaction resumes, release the token on view change/disappearance/shutdown, and let the existing 750 ms coalescer publish at most the newest dirty bundle afterward. Do not serialize a bundle while a scrub or its urgent detail load is active.
11. Instrument the cache/display decision separately: record requested visible/load ranges, prepared hit/miss, render-model hit/miss, selected display source (`detail`, `overview`, or unavailable), model's honest range, and load latency. Add invariants/tests that a displayed detail model covers the complete visible range and that overview remains visible until a covering detail model is ready.
12. Reproduce the post-full-playback broad scrub with the coverage strip. If a prepared covering entry exists but raw decode still starts, fix lookup/shape/range/subsumption logic. If prepared coverage was legitimately evicted, evaluate protection/retention from measured bytes before increasing budgets. If prepared data exists but render-ready data does not, construct the bounded render model from prepared series without blanking the current overview.
13. Keep all changes inside existing playback, Graph, Timeline, toolbar/command, and cache components. No document-format changes, external dependencies, general UI architecture rewrite, or Canvas path caching belongs in this phase.

### Goal-Driven Execution

1. Add pure cadence tests covering leading updates, suppressed intermediate updates, independent 30 Hz/10 Hz channels, identity changes, monotonic and backward movement, and forced exact publication on pause, scrub end, discrete seek, range boundary, and log switch.
2. Add focused view/state tests proving the exact cursor can advance repeatedly while static playback controls and command capabilities do not change; the secondary/readout channels update within their bounds and end exact.
3. Add persistence tests for overlapping playback, direct-interaction, and frontier suspensions; rapid scrub bursts must produce zero encodes while active and at most one coalesced newest-bundle write after quiescence. Cancellation/view exit must not leave persistence permanently suspended.
4. Add coverage-policy tests for rapid forward/backward jumps, honest render-model ranges, overview continuity, and a prepared full-pass followed by reverse/random scrub without raw decode for covered ranges.
5. Run the same controlled live sequence on the same log and hardware: idle, warm playback without interaction, aggressive scrub, complete playback, then broad reverse/random scrub. Keep separate Time Profiler and logging traces so background loads cannot be mistaken for UI work.
6. Require steady playback to leave `Graph.CursorWindowLayer` at exact cadence, Timeline/Craft at no more than 30 Hz, readouts/status/commands at no more than 10 Hz, and `DocumentHomeView`/Sidebar/static transport controls near zero steady-state cursor-driven body updates.
7. Require a material measured improvement rather than only passing tests: at least a 40% reduction in warm-playback main-thread sampled CPU against the 2026-08-05 baseline, no recurring whole-window layout chain attributable to the timestamp/speed slider, and no visible playback hitch in the acceptance log.
8. Require active scrubbing to show no prepared-series encoding/store stack, retain immediate pointer-to-Graph response, and force every sampled control to the exact final cursor on release.
9. After a complete playback with prepared coverage present, require broad reverse/random scrubbing to keep at least the overview continuously visible and never show an empty trace region. Covered ranges must not start raw decode; any legitimate uncovered range must show overview until detail arrives.
10. Run focused app tests, complete macOS Beta build, generic iOS Simulator Beta build, and document/view shutdown tests for any new presentation state or suspension token. Remove diagnostic-only instrumentation after the acceptance evidence is captured.

Completed outcome:

- Added independent 34 ms secondary-motion and 100 ms readout channels with forced exact semantic boundaries; Timeline, Craft, inspector values, timestamp, command state, and external Graph viewport publication consume the appropriate cadence.
- Isolated the timestamp and live Craft canvas from layout-stable controls/inspector structure, deduplicated Graph viewport state writes, and suspended prepared-series persistence during direct Graph interaction as well as playback/frontier construction.
- Live profiling found a larger hidden cost than the original UI hypothesis: package-backed reference cursor writes synchronously rebuilt the complete reference list and SHA-256-hashed every source. Cursor publication is now coalesced after 750 ms of quiet, explicit persistence flushes the final position, and reference-state-only changes update metadata without the structural replace/hash path.
- Apples-to-apples final playback sampling fell from 16,700 to 12,936 CPU ms and from 14,373 to 11,322 main-thread ms while `drawSeries` sampling rose from 153 to 1,154 ms, showing more delivered Graph frames rather than blocked ticks. The final aggressive scrub contained zero SHA-256, source replacement, persistent Graph encoding, raw point loading, or viewport-series work; input intensity varied between manual captures, so raw scrub CPU is not used as a percentage claim.
- Playback availability now has two gates: the selected context must contain decoded frames and a valid time domain, and Graph mode must additionally have a `.loaded` render model for that exact log. The Graph surface publishes owner-scoped readiness to the window playback controller; stale/disappearing surfaces cannot clear a replacement surface. Toolbar controls, focused commands, and `play()` itself use the same gate, so neither a click nor a keyboard/UI race can enter the playing state early. The whole playback control capsule owns disabled interaction, including the speed slider, and renders disabled content in secondary styling at half opacity.
- Verification: 86 cadence/cache/state tests, 35 context-readiness/state tests, 11 focused playback-controller tests including surface readiness and stale-owner races, the complete post-fix app-hosted suite (652 XCTest tests plus 30 Swift Testing tests), all 151 AirframeUI tests, and fresh macOS plus generic iOS Simulator Beta builds pass. Temporary signpost instrumentation was removed after capture.

## UI Corrections: Frequency Response, Playback, and Log-Switch Focus (Implemented 2026-08-04)

### Think Before Coding

- Keep the fixes in presentation and focus ownership: no analysis, persistence, document-format, or shared chart-layout changes.
- Treat the Sidebar selection as a focus transfer that must be reclaimed by the reused log-detail view when its stable log context changes.

### Simplicity First

- Use the same full-width header layout for Frequency Response guides as for axes, reserve a 28-point top inset for chips that share a canvas with a top crosshair chip, and draw playback state inside an explicit fixed-size button segment.
- Reuse the existing `@FocusState`; remove its redundant tap write and restore it when `LogContext.stateKey` changes.

### Surgical Changes

- `ResponseGuideRow` now uses a leading detail stack with a full-width header, so its visibility control remains trailing regardless of one-line or per-axis details.
- `ChartMarkerChips` accepts a source-compatible custom top inset for ordinary top-attached chips. Frequency Response Gain Crossover/Bandwidth and Spectrum filter/max-noise chips use 28 points, while explicitly on-line RPM-notch chips retain their exact line position.
- The crosshair audit found no additional conflict: Frequency Response Spectrogram has guide lines but no guide chips, and Graph has marker chips but no top crosshair chip.
- The playing background fills the complete 30-by-20-point leading playback segment through the divider.
- Log switches refocus `LogDataView` without recreating it or changing `LogViewCommandBroker`.

### Goal-Driven Execution

- Completed: all 140 AirframeUI tests, including custom and default marker-chip inset coverage, pass.
- Completed: macOS and generic iOS Simulator `Airframe Beta` builds pass.
- Remaining acceptance: visually confirm the supplied Frequency Response and playback cases and exercise shortcuts immediately after repeated Sidebar log changes.

## Graph Interactive Cache Throughput (Render Retention Correction Complete 2026-08-04)

### Think Before Coding

- Measure separately the latency and allocation cost of Reader range decode, analysis projection/min-max bucketing, prepared-series lookup, render-model construction, and Canvas drawing during representative scrubbing and 1x/30x playback.
- Treat the live finding as a fill-policy problem first: the 384 MB macOS prepared cache used only 7–10 MB, while overlapping misses repeatedly decode raw frames.

### Simplicity First

- Keep each individual render model bounded to its ordinary load window while allowing many such models to remain resident within an explicit byte budget.
- Extend preparation through reusable fixed windows before introducing a new general-purpose time-series database or loading the complete full-resolution log.

### Surgical Changes

- Give `Graph.Surface` prewarm a stable log/section/zoom/direction identity so ordinary render updates do not cancel and restart the same frontier. Start it after a 20 ms publication yield instead of the 180 ms gesture debounce.
- Fill a directional frontier beyond one neighbor up to the actual prepared-cache byte budget with exactly two concurrent decode workers. The user-initiated worker builds the next ordinary detail window. The utility worker merges up to four farther overlapping windows into one larger compact chunk and scales its point budget with duration so density remains unchanged. Prebuild render models only for near windows.
- Avoid repeated overlapping Reader decode by consuming the existing main-frame chunk tier where practical or by adding a graph-specific fixed multi-resolution tile builder. Do not enlarge the Canvas model until it can binary-slice visible points and segment gaps in a sorted linear pass.
- Coalesce persistent Graph publication across the complete frontier; a growing bundle must not be encoded and rewritten once per tile.
- Replace the render cache's fixed 24-entry ceiling with a platform-specific byte budget. Preserve global LRU ordering and trim to a lower target under memory pressure.
- Resolve Timeline In/Out through the same stable `LogContext.stateKey` used by toolbar, playback, and Graph; raw segment indexes are not sufficient for remapped source/reference logs.

### Goal-Driven Execution

1. Completed: add pure coverage/order tests and implement a stable, directional, byte-budget-bounded prepared-series frontier with two concurrent workers and duration-scaled background chunks.
2. Completed: prebuild the nearest eight render models and coalesce the complete frontier into one debounced persistent write.
3. Completed: binary-slice each series to the visible points (plus continuity neighbors) and segment sorted gaps in a linear pass.
4. Completed: pass 134 AirframeUI package tests, 17 focused app cache tests, and Beta builds for macOS and generic iOS Simulator.
5. Completed: allow covering prepared detail during interaction-tier overview selection. Reverted the partial-detail retention experiment after it produced empty playback regions; overview again fills any complete-coverage miss.
6. Completed: add a range-only, document-scoped detail coverage projection and a separate three-point opaque Timeline strip for no detail, active loading/prewarm, prepared series, render-ready models, and displayed detail. Correct its Timeline/cache join to use `LogContext.cacheLogID` after live inspection proved cache data existed under the remapped identity while the baseline-only strip queried the raw model ID. AirframeUI passes 137 tests and the macOS Beta app builds.
7. Completed: correct prepared-hit render ranges so a viewport-covering entry cannot claim the wider request outside its actual data. This restores honest displayed/render-ready coverage and lets the existing overview fallback activate before playback reaches a point-free region.
8. Completed: fix Timeline In/Out lookup to use `LogContext.stateKey`; replace the render cache's fixed 24-window ceiling with approximate retained-byte budgets (192 MB normal / 64 MB pressure target on macOS, 64 MB / 24 MB on iOS). Render models now compete in one global LRU, so a complete playback may retain substantially more than 24 small windows while document shutdown still clears all entries.
9. Completed: remove the redundant displayed/visible-detail color from the coverage strip and darken the remaining solid loading, prepared, and render-ready palette, with render-ready as the darkest green state.
10. Next only if live acceptance still shows misses: use the strip to select the transition to instrument, then measure decode/projection/render publication latency and remove repeated raw decode through chunk reuse or fixed graph tiles only if it remains dominant.
11. Live acceptance: verify correct In/Out markers, uninterrupted detail during long scrubs and maximum-rate playback, persistent render-ready coverage after one complete pass, bounded RAM, and correct close teardown.

## Document Task and Memory Lifetime Regression (Complete 2026-08-04)

### Think Before Coding

- Measure Graph playback cadence, write frequency, outstanding tasks, cache-object lifetime, and resident memory. Separate live retained graph data from memory that the allocator keeps reserved after deallocation.
- Treat playback and visible graph loading as higher priority than disposable persistence. Closing a document must end document-owned work and release its hot caches.
- Audit global window registries separately from cache budgets: one retained command closure can keep the complete document graph alive even after all explicit cache shutdown calls run.
- Treat close-time container work as another memory boundary: an unchanged close must not materialize a second document snapshot or rewrite all live blobs merely for maintenance.
- Trace representative decoded-log allocations to process roots while the live app has no document open; distinguish allocator reservation from live `Data`, decoded scans, view graphs, and tasks.
- Treat a close notification as a state transition: after `willClose`, no delayed SwiftUI callback may repopulate a global window registry for that same live window object.
- Profile a fresh idle process after the broker fix separately: surviving native windows/hosting roots and task-owned analysis work are independent roots and require independent teardown.

### Simplicity First

- Keep one latest pending write per graph dataset identity and debounce/coalesce it after interaction becomes idle. Never queue full bundle snapshots for every viewport or prewarm result.
- Add explicit document-cache shutdown/clear APIs rather than relying only on memory-pressure notifications.
- Empty and detach the existing native hosting root at close instead of introducing a second document/resource ownership architecture.
- Extend the existing command broker with one weak-identity closing-window guard; do not add another document owner or duplicate registry.
- Make the existing activity counter own its workers and make the native document window the synchronous UI-root boundary; do not introduce a second document runtime hierarchy.

### Surgical Changes

- Change only persistent write scheduling, cache lifetime cleanup, and focused instrumentation/tests. Preserve graph calculation, render models, cache format/version, and normal visible-data behavior unless measurements require a format adjustment.
- Make `NSWindow.willClose` the authoritative command-broker cleanup boundary; keep SwiftUI disappearance cleanup as an idempotent secondary path.
- Reject all broker setters for a window after its `willClose` notification, while allowing a newly allocated window even if the runtime later reuses an old address.
- Make successful `NSDocument`/`UIDocument` close explicitly sever all source-byte and decoded-state roots so delayed platform-wrapper deallocation cannot retain hundreds of megabytes.
- Restore selected-log initialization order without changing storage keys or document-state format.
- Add cancellation only at confirmed whole-log hot loops and clear the two confirmed omitted RAM stores; preserve analysis results and cache formats.

### Goal-Driven Execution

1. Add deterministic tests proving repeated graph stores coalesce and superseded payloads are released.
2. Cancel pending document-owned persistence and clear document RAM caches on close/disappear.
3. Skip persistence construction and full compaction on unchanged close while preserving mutation-driven deletion compaction.
4. Profile playback and close-time memory with a representative large log.
5. Run focused cache/graph tests plus complete macOS and iOS builds.
5. Prove a broker-held closure releases its captured document lifetime token on window close.
6. Verify OpenModel and Workspace shutdown empty decoded logs, flight information, histories, source payloads, and transient state.
7. Prove a closed native window releases its hosting controller/view while its document wrapper remains alive, and prove a stored non-first log wins initial selection resolution.
8. Completed: the regression posts `willClose`, invokes every broker setter afterward, and verifies the entry and captured lifetime state remain absent; it also proves the weak barrier does not retain the window and preserves popup filtering.
9. Completed live acceptance both without and with persistent caching: after repeated large-document open/analyse/close cycles, physical footprint settled from a 1.0 GB peak to 145.6 MB without disk caching and 220.9 MB after exercising many cache-producing views. Both runs had idle CPU and zero live platform documents, document open models, workspace/hosting controllers, activity counters, and document-owned queried caches. The cache-enabled run persisted 91 entries / 40,859,018 bytes, closed Graph persistence with zero pending writes, and emitted no later writes. Remaining high RSS was allocator-reserved empty address space, not retained document data.
10. Completed: a fresh live process proved three retained native windows/hosting roots and uncancelled detached health workers after the broker entry count reached zero.
11. Completed: `window.performClose()` now synchronously releases its hosting controller/view; ActivityCounter cancellation reaches detached workers; initial scan, Reader range/projection, motor anomaly, and motor-poles work cooperatively stop.
12. Completed automated gate: AirframeUI, BlackboxReader, and BlackboxAnalysis package suites, 10 focused macOS lifecycle/cancellation tests, and the signed macOS Beta build pass.

## Persistent Derived-Data Cache (Approved 2026-08-03)

### Think Before Coding

- Persist only reproducible processed data for package-backed document logs. Keep source bytes authoritative and treat cache deletion, corruption, and OS purging as misses.
- Use fixed platform defaults because quota is a device-local user preference: 2 GB iOS/iPadOS and 5 GB macOS. Do not query storage capacity.

### Simplicity First

- One actor-owned OS cache root, one SQLite LRU catalog, and one binary integrity envelope. Each dataset supplies its own static version and optimized payload.
- Use exact decimal 100 MB units across the common 0...10 GB Settings slider. No migration; invalid versions recompute.

### Surgical Changes

- Add `AirframeCache`, app preferences/runtime, Settings controls, and package-backed Reader scan integration. Do not change source document formats or raw-log behavior.
- Keep existing in-memory view caches as the hot tier and add persistent adapters only for stable, expensive semantic datasets.

### Goal-Driven Execution

1. Verify quota, corruption, LRU, zero-disable, and platform-default behavior with focused tests.
2. Resolve quota before the first persistent lookup and save cache writes outside foreground loading.
3. Show configured quota, current usage, and explicit clear behavior in Settings.
4. Run package tests and complete macOS plus generic iOS Simulator builds.

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
