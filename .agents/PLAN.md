# Current Plan

## Copyable Start Coordinates And Resilient Reverse Geocoding (Implemented; Live Acceptance Pending 2026-08-17)

### Think Before Coding

- Coordinate interoperability is the invariant: render latitude then longitude with fixed five-digit POSIX decimal points and one comma separator, independent of the UI locale. Reverse-geocoded place names remain optional, non-persisted runtime data.

### Simplicity First

- Reuse the existing document-owned `FlightLocationStore`, shared Overview/Map environment boundary, MapKit client, bounded LRU, memory-pressure hook, and shutdown path. Add only one shared formatter and one injectable `NWPathMonitor` seam; add no setting, dependency, or persisted state.

### Surgical Changes

- Overview and Map inspector now share selectable `48.13720, 11.57550` text. The Overview coordinate row no longer navigates so selection is reliable. The store suppresses known-offline requests, uses a capped 30/60/120/240/300-second retry schedule, immediately retries after unavailable-to-available network recovery, deduplicates requests, and cancels network/request/retry work on eviction or shutdown.

### Goal-Driven Execution

- Focused `LogViewSelectionTests` cover format, caching, request deduplication, offline suppression, immediate network recovery, capped backoff, automatic retry-to-success, memory-pressure cancellation, and permanent shutdown. Remaining acceptance is one live macOS offline/open/reconnect/copy-paste/close pass with a writable GPS document.

## Website Wiki: Dynamic And RPM Notch Overlays (Implemented 2026-08-16)

### Think Before Coding

- Keep recorded spectrum energy, tracked filter centres, firmware-matched calculated attenuation, and evidence quality conceptually separate. Never describe the grey response field as measured post-filter energy.

### Simplicity First

- Extend the existing filter-tune guide and add one reusable notch-overlay concept. Reuse the current content schema, gallery, screenshot registry, and static renderer without adding routes, CSS, JavaScript, or dependencies.

### Surgical Changes

- The private screenshot fixture now includes the publication-approved BF 2026.6.1 source as the neutral `Notch Filter Tune` role. Two matched Frequency-vs-Throttle captures show the collapsed line-only state and the expanded, highlighted Dynamic-notch attenuation state; the raw source remains private.

### Goal-Driven Execution

- Fixture reconstruction and semantic notch validation pass for seven named segments, five presets, and seven future UI states. All seven website tests, content validation, and the 20-page preview build pass. The guide and glossary explain Q, Weight, Fade, LPF, all evidence labels, Spectrum-mode differences, version limits, cascaded notches, and why predicted attenuation cannot certify a tune or physical safety.

## Spectrum Blade-Pass Harmonics (Implemented And Documented 2026-08-16; App Visual Acceptance Pending)

### Think Before Coding

- Keep physical meaning and reference frame explicit. With blade count `B`, the fundamental blade-pass order is `B×` mechanical motor frequency; its second and third harmonics are `2B×` and `3B×`. Configured RPM-notch harmonics remain actual Betaflight gyro filters even when their geometry coincides with a blade-pass guide.
- Treat a conservative automatic blade-count result as immediately useful transient aircraft context. A stored user value remains authoritative, but Save is not a prerequisite for rendering guides when detection already has a result.

### Simplicity First

- Reuse the existing Spectrum Guides section, document-wide visibility setting, overlay renderer, info popover, and hover/pin behavior. Store only the three individual blade-pass selections in the existing Spectrum settings payload.

### Surgical Changes

- In Frequency vs RPM, always offer the fundamental plus second and third blade-pass harmonics as independent Guide rows whenever either a stored numeric blade count or an automatic two-/three-blade result is available. A stored value wins. Derive optional fourth through sixth rows from that effective blade count, recorded mechanical-RPM span, and Nyquist: an additional order must remain in-band over at least 25% of that span. Label motor orders directly, render only selected lines that intersect the current frequency window, and keep Filters unchanged. Each row follows the shared sidebar selection layout with its color dot left and selection circle at the trailing edge; line, chip, selection accent, and dot share a harmonic-specific shade from one green family. Show the effective count beside the size profile, for example `5″ Freestyle, 3 Blades`; when neither stored nor inferred, show `Other / Unknown` instead of hiding the blade context. Migrate Spectrum settings storage from version 5 to 6 with only the first three selected by default.

### Goal-Driven Execution

- Focused Spectrum model/settings tests pin harmonic multiplication, adaptive higher-order availability, default-off extra selections, persistence/migration, visible-window rejection, invalid inputs, harmonic color roles, inferred-count fallback, and stored-count precedence. All 49 focused app tests, 197 AirframeUI tests, 40 AirframeCaptions tests, the macOS test build, and the iOS Simulator build pass; live app visual acceptance remains. The public wiki now explains what the guides show, how to interpret moving ridges, harmonic numbering, individual selection, automatic-count availability, and the distinction from real RPM-notch filtering. Its real macOS capture shows the current green-family fundamental, second, and third guide rows and lines.

## Website Wiki: Aircraft Settings And Spectrum Interpretation (Implemented And Refined 2026-08-16)

### Think Before Coding

- Separate optional aircraft context from Spectrum interpretation. The Aircraft Settings guide explains what users can add and where that context helps. The Spectrum guide explains the three views, visual patterns, blade-pass orders, and the limits of those observations without turning either article into implementation documentation.

### Simplicity First

- Keep the English Getting Started guide at `/inside-airframe/aircraft-settings/` focused on aircraft context and publish the foundational Tuning guide `/inside-airframe/read-spectrum/` for interpretation. Reuse existing structured blocks, retain the `overview` screenshot ID, add only `blade-pass-guide`, and leave renderer, schema, templates, CSS, and JavaScript unchanged.

### Surgical Changes

- Keep the real macOS Overview capture in Aircraft Settings and place the current full-window Frequency-vs-RPM capture in Read Spectrum. The new Spectrum article teaches Frequency, Frequency vs Throttle, and Frequency vs RPM before introducing `3×`, `6×`, and `9×`, their individual controls, their green guide lines, and the distinction from RPM-notch filters. Adjacent vibration and filter guides link to this shared foundation.

### Goal-Driven Execution

- The seven website tests, content validation, and 20-page build pass. Desktop DOM review confirms both routes, their headings, tables, links, intrinsically sized screenshots, and absence of horizontal overflow; narrow browser automation remains pending because the collaborative preview could not resize its existing tab. Aircraft Settings now stays on optional context and confirmation, while Read Spectrum covers the three views, the fundamental and higher blade-pass orders, ridge classification, individual selection and hover highlighting, and the RPM-notch distinction.

## Propeller Blade Count And Blade-Pass Guide (Implemented 2026-08-16; Real-Log Classification Acceptance Pending)

### Think Before Coding

- Treat blade count as user-owned aircraft metadata. Frequency analysis may supply evidence for a draft suggestion but cannot uniquely determine every blade count because motor, structural, and higher-order blade harmonics overlap.

### Simplicity First

- Reuse propeller size's document-default/log-override storage, Overview row, shared Aircraft Settings save flow, `Choose …` wording, and existing Spectrum RPM coordinate conversion. Offer only two- versus three-blade suggestions; keep four blades and ambiguity manual.

### Surgical Changes

- Add one additive state key, one dependency-free analysis outcome, localized captions, and one dashed `B×` Frequency-vs-RPM guide. Do not alter FFT results, cache formats, automatic motor-layout persistence, or upstream repositories.

### Goal-Driven Execution

- Synthetic analyzer tests cover strong two-blade, strong three-blade, ambiguous, and insufficient-RPM-span cases. Full BlackboxAnalysis and AirframeCaptions suites, focused document-state repository/store tests, and macOS/iOS builds pass. Overview/Spectrum now own the live Blade and Layout inference state: the Aircraft card and an open Aircraft Settings dialog show inline row spinners, the dialog stops adopting a field after manual input, and an adopted result gets an info-button tooltip/popover instead of a separate explanation row. Layout inference no longer persists before Save. A live large-log pass confirmed the complete cached Frequency-vs-RPM heatmap and blade-pass diagonal. That pass also isolated the reported AppKit constraint loop to SwiftUI's native macOS inspector hosting rather than the sheet or overlay; macOS now uses a stable 320-point in-hierarchy sidebar while iOS/iPadOS retains the native inspector. The dedicated macOS XCUITest compiles but remains skipped by the runner's established foreground-activation gate. Git LFS is available and the curated macOS website captures now cover the saved aircraft card and confirmed `Blade Pass · 3×` guide. Remaining acceptance is classification against labeled two-, three-, and four-blade real logs plus populated/empty iOS/iPadOS visual review.

## Firmware-Faithful Dynamic and RPM Notch Overlays (Implemented 2026-08-15; Live Visual/Profile Acceptance Pending)

### Think Before Coding

- Route Betaflight 4.4, 4.5, 4.6, 2025.12, and 2026.6 through explicit firmware models while also checking the segment's actual headers and recorded fields. Unknown generations retain observed centers and configured limits but never receive an assumed attenuation formula.
- Treat each selected log segment's Blackbox headers and time series as authoritative. Imported FC configuration never replaces historical notch settings.

### Simplicity First

- One semantic overlay model owns configuration, evidence, segmented tracks, and bounded dB grids. One dependency-free response kernel covers the historical biquad and current TPT-SVF state equations, weighted complex crossfade, fade, cascades, and Betaflight's coefficient trig approximation.
- Frequency and Frequency vs Throttle reuse pane-targeted render primitives; Frequency vs RPM preserves its existing center diagonals and selection state without adding an attenuation field.

### Surgical Changes

- Existing static filter overlays and three RPM harmonic selections remain compatible. Dynamic Notch adds one persisted, default-off selection. RPM response cache semantics advance to version 2 and Dynamic response uses its own version-1 dataset.
- Spectrum cache shutdown is terminal and rejects late publications. No `.airframe` document data, external dependency, or upstream reference checkout is modified.

### Goal-Driven Execution

- Reader, Analysis, Captions, and AirframeUI package suites pass, as do focused app settings/cache tests and macOS/iOS Simulator builds. A private BF 2026.6.1 document confirms Dynamic count 1, Q 2.20, 90–650 Hz, observed Roll `debug[1]`, three modeled RPM harmonics, Q 3.50, 100% weights, 50 Hz fade, 150 Hz LPF, and a 250 µs PID looptime.
- A synthetic maximum grid (1,024 snapshots, 2,048 bins, seven Dynamic slots, and three 8-motor RPM cascades) completed in 7.845 seconds in a debug Swift test after coefficient and unit-circle preparation were hoisted out of the inner notch loop. Remaining acceptance is a live macOS/iPad visual pass plus a 300-second document Time Profiler run. Verify resize/zoom do not restart analysis and repeated close rejects every late cache publication.

## Reusable Aviation Instruments And Map HUD (Implemented; Live Acceptance Pending 2026-08-13)

### Think Before Coding

- Keep instrument API, pure fixed-size projection, Canvas rendering, Map layout, cursor adaptation, and document/preset persistence as separate boundaries. Preserve the full attitude basis through the public contract and validate it before drawing.

### Simplicity First

- Own three independent renderers in `AirframeUI`: Heading Tape, generic Vertical Tape, and Attitude Indicator. Reuse Vertical Tape for Speed and Altitude; add no protocols, dependencies, cache, timer, task, or instrument ViewModel.

### Surgical Changes

- Add one `AviationInstruments` package area, one Map HUD/driver file, four additive default-on Map settings, localized inspector/accessibility captions, and focused tests. Preserve MapKit, route/annotation identity, Timeline, existing cache owners, and the independent Heading Cone setting.

### Goal-Driven Execution

- Pure projections enforce 13/11-tick bounds and finite attitude geometry, including North crossing, negative/extreme tapes, inverted/near-vertical attitude, invalid bases, and compact/standard HUD metrics. Package and focused app tests cover legacy defaults, independent persistence, preset archive round trips, Craft preparation policy, and equality-gated field publication. Complete macOS tests/build, iPad Simulator build, and live playback/performance acceptance before closing the remaining task.
- The Map-only GS unit control keeps the reusable Vertical Tape passive, converts canonical m/s to km/h only in the presentation leaf, and persists its additive default-m/s setting through documents and presets. Its 44-point semantic Button intercepts only the unit area.

## iOS/iPadOS-Native Aircraft Settings (Implemented 2026-08-10)

### Think Before Coding

- Treat Aircraft Settings as a short modal editing task. Preserve the current macOS sheet unchanged and isolate the iOS/iPadOS presentation behind a platform-specific view.
- Keep the existing draft-state and save semantics: Cancel discards the two local selections; Save publishes both values once and dismisses.

### Simplicity First

- On iOS/iPadOS, use one `NavigationStack` containing a native grouped `Form`, with the system navigation title `Aircraft Settings`.
- Put `Cancel` in a `.cancellationAction` toolbar item and `Save` in a `.confirmationAction` toolbar item. Remove the in-content hero/title and bottom action bar on iOS/iPadOS.
- Present one clearly labeled row per setting: `Propeller Size` and `Motor Layout`. Keep native menu pickers and their current option order.
- Put the existing explanation in a form section footer so it remains available without competing with the navigation title.
- Let `Form` own grouped row and canvas backgrounds. Remove the custom secondary control card and explicit sheet background on iOS/iPadOS.

### Surgical Changes

- Split only `AircraftSettingsView` presentation code. Reuse its inputs, local state, compatible-layout calculation, captions, save closure, call sites, and accessibility identifier.
- Add no dependency, model change, document-format change, navigation-route change, or macOS visual change.
- Keep user-facing text localizable and use semantic toolbar placements rather than hard-coded leading/trailing positions.

### Goal-Driven Execution

- iPad and iPhone previews cover the platform-specific presentation. A focused UI test opens a real Airframe document, verifies the navigation title, both labeled pickers, semantic Cancel/Save actions, captures the sheet, and verifies Cancel dismissal.
- The focused UI test passes on the iPad (A16) iOS 26.5 Simulator. Its screenshot verifies the grouped background, labeled rows, explanatory footer, centered title, and leading/trailing toolbar actions.
- The macOS app build passes. The iPhone 17 Pro iOS 26.5 build completes, but a compact-width UI-test rerun hit an Xcode 26.5 debugger/test-session finalization failure after the simulator returned to Home; compact live acceptance remains part of the general iPad/iPhone audit.

## Polar Frequency vs Throttle Exploration (Planned 2026-08-08)

### Think Before Coding

- Treat this as an alternate projection of the existing `frequencyVsThrottle` heatmap, not a new analysis mode. `Frequency vs RPM` remains Cartesian. The existing per-axis panes, FFT results, heatmap normalization, intensity, Hanning option, signal selection, overlays, frequency window, range measurement, loading/error behavior, and cache identity keep their semantics.
- Add a `Frequency vs Throttle` presentation enum with `Cartesian` and `Polar`. Use these standard coordinate-system names in the English UI. Show its menu-style picker in the Spectrum `View` section only while `Frequency vs Throttle` is active. Default existing and new state to `Cartesian`.
- Map frequency monotonically to radius and throttle clockwise from 12 o'clock. Treat heatmap rows as angular cells: the 0% cell begins immediately clockwise/right of the seam and the 100% cell ends immediately counterclockwise/left of it. The cells never share the same painted angle even though their outer boundaries meet at 12 o'clock.
- Define projection behavior before rendering: each axis gets one centered square polar plot; the visible frequency window maps to the available radial span, with a nonzero lower bound producing an annulus. Frequency rings retain absolute labels, and throttle spokes are labeled at useful percentages without duplicating the 0%/100% seam label.
- Classify cadence per `doc/ui-performance.md`: heatmap values and bitmap colors are semantic prepared input; Cartesian/polar warping, rings, labels, overlays, and pane layout are geometry work; crosshair, pan, zoom, and range-selection feedback are interaction work. No FFT, bitmap rebuild, document scan, or persistence may occur merely because the presentation changes or geometry updates.
- Scope the first implementation to iPadOS under the current platform rule; preserve the frozen macOS presentation. Keep the presentation setting platform-local in behavior even if its storage type is shared. Reconfirm macOS scope before implementation if the experiment is intended on both platforms.
- Ownership remains unchanged: render values and interaction state are document/view scoped, existing compute tasks and result cache retain shutdown responsibility, and the polar renderer introduces no long-lived cache. Persistent caching does not improve this geometry-only projection and must not be added.

### Simplicity First

- Reuse `StackedHeatmapRenderModel` and each pane's existing immutable `SpectrumHeatmapImage`. Add a dedicated polar heatmap surface and a small pure projection model instead of branching throughout the Cartesian canvas.
- Warp the prepared rectangular bitmap into bounded polar wedges at draw time, clipped per pane. If SwiftUI `Canvas` cannot transform the bitmap accurately and smoothly, prepare one polar `CGImage` per pane off-main only when the heatmap image, intensity, or output resolution class changes; do not rasterize on pointer, pan, zoom, or every resize tick.
- Centralize forward and inverse transforms: `(frequency, throttle) -> point` and `point -> (frequency, throttle)`. Use them for bitmap/wedges, rings, spokes, filter overlays, marker chips, crosshair readout, hit testing, zoom anchoring, pan, and radial range selection so visual and interactive semantics cannot drift.
- Convert existing throttle-mode overlays by meaning: fixed-frequency vertical lines become rings; throttle-dependent frequency curves become polar paths; highlighted/normal opacity and line styles remain unchanged. RPM-only diagonal overlays remain on the Cartesian RPM heatmap.
- Preserve one graph per available Roll/Pitch/Yaw axis. Use the existing stacked vertical order and titles; each pane reserves a square plot inside its band rather than stretching the circle.

### Surgical Changes

- Add the localized `Cartesian`/`Polar` captions, picker title, help/accessibility text, and stable accessibility identifier through `AirframeCaptions` and `.xcstrings` only.
- Extend Spectrum settings/storage by one backward-compatible field and storage-version bump. Decode older state as `Cartesian`; include the choice in document and preset round trips without changing analysis/cache keys. Switching presentation rebuilds projection only.
- Keep `StackedHeatmapSurfaceCanvas` and its tests unchanged for Cartesian and RPM rendering. Add sibling polar projection/surface/crosshair types in `AirframeUI`, selected only by the `frequencyVsThrottle` iPad surface.
- Adapt the existing interaction layer rather than broadening the static renderer's observations. Crosshair motion stays in a leaf overlay; it shows frequency plus throttle and repeats the corresponding radial/angular guides in each axis pane. Pointer positions outside the circle or inside an annular hole produce no heatmap readout.
- Preserve frequency zoom limits, reset, accessibility adjustment, and persisted window. Pinch/scroll zoom is radius-anchored; frequency pan changes the radial window. Do not assign rotation or angular panning because throttle always represents the fixed 0...100% circle.
- Preserve X-range measurement as frequency-range measurement. In Polar, the committed selection is a radial interval within the active pane; publish the same frequency-domain selection and existing heatmap result behavior. Keep measurement gesture precedence, filter-chip exclusions, pointer exit, and reset behavior intact.
- Keep marker chips readable outside the circle and collision-bounded. Derive their anchors from the polar geometry, but preserve their IDs, highlight linkage, labels, and selection behavior.
- Do not modify `BlackboxAnalysis`, raw matrices, result-cache formats, upstream reference repositories, document format version, Cartesian visual output, or unrelated Spectrum modes.

### Goal-Driven Execution

1. Lock projection semantics with pure tests: cardinal throttle angles, separate 0%/100% seam cells, frequency-radius round trips, annular windows, boundary clamping, pane hit testing, and square fitting at narrow/wide sizes.
2. Add settings/caption tests: old storage defaults to `Cartesian`, new state and presets round-trip both values, the picker appears only for `Frequency vs Throttle` on iPadOS, and no presentation change alters compute/cache identity.
3. Render heatmap cells plus grid in the polar surface. Golden or pixel probes verify frequency increases outward, throttle increases clockwise, the final throttle bin stays left of 12 o'clock, no seam overlap/gap is visible, circles remain circular, and Roll/Pitch/Yaw keep independent panes.
4. Add overlay tests for fixed-frequency rings and throttle-dependent curves, including clipping to the frequency window and highlighted/normal styles.
5. Add inverse-projection and interaction tests for crosshair values, outside/hole rejection, radial zoom anchor, pan/reset, radial range selection, marker-chip exclusion, accessibility adjustment, and pointer exit.
6. Run focused AirframeUI and app settings/model tests, then the complete relevant package suites and iOS Simulator build. The macOS build must still pass and its Spectrum UI/output must remain unchanged.
7. Perform live iPad visual and interaction acceptance in portrait, landscape, narrow split view, and full width with one-, two-, and three-axis signal groups. Verify Dynamic Type, VoiceOver, Reduce Motion, touch/pencil/pointer, 0%/100% seam readability, zoomed annuli, overlays, chips, intensity, Hanning changes, and range measurement.
8. Profile a representative large log with SwiftUI Instruments/Time Profiler while switching projection, resizing, moving the pointer, measuring, zooming, and panning. Require no FFT or bitmap-color rebuild for projection/geometry/interaction-only changes, flat static-layer redraw counts during pointer motion, visible-output-bounded projection, coalesced persistence outside direct manipulation, and prompt release after repeated open/use/close cycles.

Success: On iPadOS, `Frequency vs Throttle` can switch between `Cartesian` and `Polar`; Polar shows one correct circular heatmap per axis with frequency radial and throttle clockwise from 12 o'clock, keeps 0% and 100% visually distinct at the seam, preserves every existing applicable control and interaction, and introduces no document-scale work at interaction cadence. Cartesian, RPM mode, and macOS remain unchanged.

## iOS Recent Documents (Implemented; Provider Acceptance Pending 2026-08-08)

### Think Before Coding

- Keep provider authorization as persistent bookmark data and let the existing `AirframeUIDocument` lifecycle own active security-scope access.

### Simplicity First

- One device-local versioned store retains at most eight independently decodable bookmark records and projects them through the unchanged `StartView.RecentDocument` UI model.

### Surgical Changes

- Only the iOS `HomeView` open paths and a platform-specific store changed. Folder imports, fixtures, document formats, iCloud state, user-facing strings, layout, and macOS `NSDocumentController` behavior remain unchanged.

### Goal-Driven Execution

- Focused store tests, the complete iOS app-test bundle, and the macOS app build pass. Physical On My iPad, iCloud Drive, and third-party-provider acceptance remains tracked in `TASKS.md`.

## Spectrum Interaction And Document-State Coalescing (Implemented; Live Acceptance Pending 2026-08-07)

### Think Before Coding

- Separate Spectrum interaction cadence from document-state publication and keep domain mutations independent from UI-state save cadence.

### Simplicity First

- Spectrum commits only at interaction boundaries; the workspace retains one latest `Metadata.State` candidate behind a one-second trailing debounce.

### Surgical Changes

- Preserve FFT, render models, document format, and the 350 ms domain-save path. Equality-gate only the existing Spectrum geometry publications and route main/reference UI state through one staging API.

### Goal-Driven Execution

- Workspace/controller and platform persistence tests, all AirframeUI package tests, and macOS/iPadOS builds pass. Physical large-log panning/resize profiling remains tracked in `TASKS.md`.

## Step Response Horizontal Zoom (Implemented; Live Acceptance Pending 2026-08-07)

### Think Before Coding

- Keep Step Response analysis/cache identity independent of its horizontal viewport. Treat semantic results, geometry projection, interaction state, and persistence as separate cadences.
- Keep the transient vertical crosshair in its own interaction-cadence overlay, with only an X/time chip and no Y readout, so pointer motion never invalidates the semantic trace Canvas.

### Simplicity First

- Use one 1x...10x time window shared by all classic Step Response panes and traces. Preserve the Y domain and leave Frequency Response/Spectrogram unchanged.

### Surgical Changes

- Persist only normalized viewport fractions in existing document/preset Step Response storage. Draw visible uniform samples plus one neighbor without adding an analysis or cache layer.

### Goal-Driven Execution

- Package policy tests, focused app persistence/preset tests, and both platform builds pass. Remaining physical interaction and profiling gates are tracked in `TASKS.md`.

## X-Range Measurement (Implemented 2026-08-07; Live Validation Pending)

### Think Before Coding

- Keep mixed X domains pane-bound and use exact display-scaled samples, reliable-only Frequency Response data, neighboring boundary samples, and recorded gaps.

### Simplicity First

- One committed environment state, one leaf-local coalesced drag draft, one native tracking layer, one bounded overlay, and one streaming statistics/extrema reducer serve every supported surface without persistence or a new cache.

### Surgical Changes

- Spectrum snap paths were removed while its pixel-bounded peak index remains. Existing chart render models stay intact; measurement tasks belong to their surfaces and reject stale publications.
- Pane-bound inspector results reuse each trace's render color, omit redundant pane names, consolidate related values into compact rows, and expose localized native help for every metric label. Oscillation output appears only for a stable estimate; rejection copy and completed-period counts remain hidden.
- Drag updates remain inside the overlay leaf, are deduplicated and capped at 120 visible updates per second, reuse precomputed domains and a retained formatter, and redraw only bounded rectangles. Calculation handles are non-observable so task replacement cannot invalidate complete chart surfaces.

### Goal-Driven Execution

- Package tests, state tests, and both platform builds pass. Complete the remaining physical gesture, large-log performance, and repeated open/measure/close lifecycle checks before declaring live acceptance complete.

## Tuning Interpretation, Filter Score, and Assistance Roadmap (Approved 2026-08-05)

### Summary

Build Airframe's tuning support in four maturity levels:

1. Explain existing measurements and improve capture feedback.
2. Add validated assessments, including a strict Filter Score.
3. Provide active but non-mutating next-step guidance.
4. Extend the existing CHIRP PID Tuning Assistant.

The roadmap separates measurement from interpretation, tune quality from evidence confidence, filter assessment from PID assessment, observations from causal diagnosis, and guidance from automatic configuration changes. Each numbered measure is independently implementable. Later measures depend on the stated earlier evidence contracts.

| Order | Measure | Maturity | Dependency |
|---:|---|---|---|
| 1 | [Contextual tuning guides](#measure-1-contextual-tuning-guides) | Views and help | None |
| 2 | [Step Response evidence and capture diagnostics](#measure-2-step-response-evidence-and-capture-diagnostics) | Views and help | None |
| 3 | [Step Response measurement expansion](#measure-3-step-response-measurement-expansion) | Neutral measurements | 2 |
| 4 | [Tune Score Key Findings](#measure-4-tune-score-key-findings) | Interpretation of existing score | Existing Tune Score |
| 5 | [Spectrum Filter Review](#measure-5-spectrum-filter-review) | Neutral measurements and visualization | Existing Spectrum |
| 6 | [Filter Score calibration and release](#measure-6-filter-score-calibration-and-release) | Strong assessment | 5 plus validation fixtures |
| 7 | [Cross-flight Tuning Review](#measure-7-cross-flight-tuning-review) | Comparative assessment | 3, 4, optionally 6 |
| 8 | [Guided next-flight actions](#measure-8-guided-next-flight-actions) | Active help, no setting changes | 4-7 |
| 9 | [Blackbox Test Setup Assistant](#measure-9-blackbox-test-setup-assistant) | Active preparation | 2, 5, FC communication |
| 10 | [CHIRP PID Tuning Assistant extension](#measure-10-extend-the-existing-chirp-pid-tuning-assistant) | PID recommendations and explicit application | 6, 8, 9 plus existing CHIRP algorithm gates |
| 11 | [Separate Filter Tuning Assistant](#measure-11-future-separate-filter-tuning-assistant) | Future active filter help | Stable Filter Score history |

### Think Before Coding

- UAV Tech and Chris Rosser provide expert interpretation, not universal thresholds. Betaflight 4.5 settings and examples never become current Airframe defaults.
- A single symptom must not map directly to one PID term. Overshoot, latency, noise, saturation, Feedforward, filtering, mechanics, and estimator quality can interact.
- Filter Score means the observed filter outcome in one flight and selected range, not a globally optimal filter configuration.
- Tune Score and Filter Score keep score and Confidence independent. Missing evidence produces `No Score`, not a lower score.
- Filter Score uses strict evidence gating: usable unfiltered and filtered gyro for Roll and Pitch, filtered D-term, motor outputs, throttle, eRPM, a valid motor-pole count, adequate duration/sample rate/throttle-RPM coverage, and repeatable measurements. D-term prefilter data strengthens evidence but is not mandatory because it is debug-mode dependent.
- No fixed `90 Hz` boundary, prop-size table, Master Multiplier limit, or Rosser example value becomes a scoring constant.
- Motor temperature, damaged-prop tolerance, mechanical integrity, and thermal headroom cannot be proven from Blackbox data and remain explicit limitations.
- Tune findings stay inside Spectrum, Step Response, Frequency Response, and the future Tuning Review. They do not become Overview log-integrity checks.
- The existing CHIRP assistant remains PID-only. It may consume Filter Score as a prerequisite and safety signal, but it never changes filters.

### Simplicity First

#### Measure 1: Contextual Tuning Guides

Add compact localized help beside existing analysis controls.

- Spectrum explains the signal path from unfiltered gyro through gyro filters and PID/D-term to motor output, RPM Filter versus Dynamic Notch responsibilities, the delay/noise tradeoff, and why measured harmonics matter more than prop-size tables.
- Step Response explains setpoint, gyro response, normalized target, peak, latency, overshoot, settling, final error, usable input, and why one curve cannot uniquely diagnose P, D, I, or Feedforward.
- Frequency Response explains Tune Score components, Confidence, CHIRP coverage, limitations, and the relationship between frequency-domain response and derived step response.
- Use native info popovers and short inspector guidance. Summarize Knowledge Base claims; do not embed copyrighted slide images or long quotations.

Acceptance: every claim maps to Knowledge Base evidence; BF 4.5 examples are visibly historical; localization, accessibility, previews, and macOS/iOS layouts pass.

#### Measure 2: Step Response Evidence and Capture Diagnostics

Replace generic failure strings with structured evidence:

- Total candidate windows.
- Windows below minimum input.
- Windows rejected by quality checks.
- Windows excluded by the selected rate class.
- Accepted windows.
- Missing setpoint, gyro, sample-rate, or range evidence.
- Selected ranges that are too short or contain no suitable moves.

Give evidence-capture help: request several clean and decisive moves on the missing axis, avoid continuous stick activity that prevents response isolation, expand or move the selected range, select the matching rate class, and identify missing firmware/logging fields without inventing replacements. Keep evidence-capture advice separate from tune-change advice.

Acceptance: structured counts exactly match calculator decisions, every unavailable result has a typed reason, and no capture message recommends a PID or filter change.

#### Measure 3: Step Response Measurement Expansion

Extend every successful axis result with:

- Existing latency: time to 50% response.
- Rise time: 10% to 90% of the normalized target.
- Peak value.
- Overshoot: `max(peak - 1, 0) * 100`.
- Settling time: the first point after which the remaining response stays within `1.0 +/- 5%`.
- Final tracking error: absolute mean error over the final 10% of samples.
- Accepted/candidate window ratio.
- Response duration and estimator method/version.

Retain the normalized `1.0` reference line. Add metrics to the existing per-log/axis presentation, show evidence counts, explain unavailable rise/settling values, and add no qualitative good/bad labels yet. Reuse CHIRP-derived step metric definitions where equivalent.

Acceptance: synthetic curves cover every metric and unavailable case; existing PIDtoolbox comparison behavior stays within current tolerance; old persistent-cache entries miss safely after the Step Response dataset version bump.

#### Measure 4: Tune Score Key Findings

Add a non-collapsible `Key Findings` block below the Tune Score summary and above component rows. Generate no more than three deterministic findings: weakest component, limiting axis, concrete supporting measurements, material Confidence/coverage limitation, and any applied hard-cap reason.

Do not change Tune Score v1 mathematics, infer a PID adjustment, repeat all component rows, combine Confidence into the score, or call a tune optimal.

Acceptance: ordering is deterministic, every finding resolves to displayed evidence, and Confidence never changes the score or finding severity.

#### Measure 5: Spectrum Filter Review

Add a descriptive `Filter Review` above the existing filter configuration. It follows the selected log and In/Out range but computes independently of the currently visible Spectrum traces.

1. Gyro input noise: unfiltered gyro spectrum, measured motor fundamental/harmonic ridges, and broadband noise outside those ridges.
2. Filtered gyro result: residual harmonic energy, broadband attenuation, and frequencies where substantial energy remains.
3. Controller output: D-term high-frequency energy, motor-output oscillatory energy, and per-axis/weakest-motor evidence.
4. Cost and configuration: gyro/D-term/total delay, RPM harmonic count and weights, Dynamic Notch configuration, missing evidence, and version limitations.

Add a compact signal-flow summary. Evidence rows may highlight their measured plot regions. Motor bands follow measured eRPM ridges. Useful-control/noise separation derives from setpoint energy and observed motor-frequency coverage, not a static `90 Hz` boundary. Show harmonic occupancy and ridge-to-background strength before discussing RPM weight efficiency. Rosser AOS/Easy values remain labeled historical BF 4.5 examples.

This measure produces no numeric score and no setting recommendation.

Acceptance: harmonic regions follow RPM in synthetic and real fixtures, missing signals produce precise limitations, and changing the displayed Spectrum field cannot change Filter Review results.

#### Measure 6: Filter Score Calibration and Release

Introduce a versioned Filter Score with the same presentation language as Tune Score: `1.0` to `10.0`, `Excellent` through `Critical`, independent High/Medium/Low Confidence, ordered `No Score` reasons, per-component facts/formulas, and a visible algorithm version.

Components:

1. `Gyro Attenuation`: post-/pre-filter spectral-energy ratios across measured harmonic bands and the derived broadband-noise region, aggregated conservatively across Roll/Pitch.
2. `D-Term Cleanliness`: normalized high-frequency D-term energy plus pre-/post-filter ratio when matching debug data exists. Recorded D gains must prevent naive absolute-amplitude comparisons across tunes.
3. `Motor Output Cleanliness`: oscillatory motor-command energy normalized against usable motor-command variation, weakest-motor evidence, motor imbalance, and separate saturation/clipping limits.
4. `Delay Efficiency`: gyro and D-term delay evaluated jointly with achieved attenuation; neither minimum delay nor maximum attenuation wins in isolation.

Use the Tune Score convention of a conservative weakest-channel plus channel-mean component result and a weighted geometric overall mean. Define safety caps only from validated evidence. Confidence never changes the numeric score. A missing required component returns `No Score`; remaining components are not silently reweighted.

Calibration gates before numerical thresholds ship:

- Synthetic signals with known filter transfer functions.
- Amplitude-scaling invariance.
- Sample-rate and FFT-resolution invariance within documented tolerance.
- Motor-ridge movement with RPM and known missing/extra harmonics.
- Clean, noisy, over-filtered, resonant, and motor-output-oscillation fixtures.
- Multiple craft sizes and operating ranges.
- Repeatability across valid windows from the same flight.
- Expert labels recorded independently of the calculated score.
- False-positive review for smooth low-excitation flights.

Record every threshold, weight, and hard cap with fixture evidence. Unsupported values remain unavailable rather than being copied from BF 4.5 guidance.

Place Filter Score at the top of the Spectrum inspector above Filter Review. Reuse the Tune Score gauge, rating, Confidence, component rows, and explanation pattern. Show `No Score` with capture instructions and state that the result was observed in the selected flight/range. Do not create a combined Tune+Filter score.

Acceptance: strict gates suppress incomplete evidence; score is invariant under supported amplitude scaling; Confidence cannot alter an otherwise identical score; aggregation/caps are deterministic; thresholds pass documented calibration review; controlled filter changes produce explainable component changes.

#### Measure 7: Cross-Flight Tuning Review

Use existing attached reference logs first. Add a comparison summary without a new document workflow.

- Show Tune Score, Filter Score, their algorithm versions, Step Response metrics/evidence, recorded PID/D Max/Feedforward/filter configuration, descriptive P:D and P:I ratios, firmware, and analysis range.
- Let the user select one reference as baseline and show values plus deltas.
- Warn instead of silently comparing different algorithm versions, firmware, filters, rate profiles, motor-pole settings, or logging methods.
- Keep Roll, Pitch, and Yaw separate. Never infer that the newest or highest-gain tune is best. Do not apply Roll/Pitch D reasoning to Yaw.
- Do not introduce an aggregate overall tuning score.

Acceptance: baseline selection and ordering are deterministic, every delta resolves to the correct segment, and incompatible comparisons remain visibly qualified.

#### Measure 8: Guided Next-Flight Actions

Add deterministic, non-mutating action cards: improve the recording, inspect an axis/signal, repeat a test, check mechanics, validate filters before PID work, collect CHIRP evidence, or stop because of saturation/severe oscillation/unreliable evidence.

Every action states its triggering evidence, why it matters, the exact next observation or flight procedure, its completion condition, and that Airframe changed no setting. Do not output numeric PID/filter values. Feedforward signatures may be described only as consistent with a condition, never as a single-cause diagnosis.

Acceptance: every action has a concrete evidence trigger; insufficient or severe evidence suppresses recommendations; no unsupported setting value can be generated.

#### Measure 9: Blackbox Test Setup Assistant

Implement the existing setup-assistant concept before PID recommendations:

- Select Filter Review, Step Response, or CHIRP.
- Read firmware generation and current FC configuration.
- Verify fields, debug mode, logging rate, eRPM, motor poles, and Blackbox device.
- Detect legacy CHIRP phase-only payloads.
- Generate version-scoped setup changes and preview every change.
- Apply only after explicit confirmation or emit a CLI diff.
- Provide test-flight and abort/safety instructions.
- Restore temporary debug/logging settings when requested.

This assistant prepares evidence. It does not tune PIDs or filters.

Acceptance: setup changes are previewed/reversible, unsupported firmware/debug layouts are blocked, and cancellation leaves no hidden FC change.

#### Measure 10: Extend the Existing CHIRP PID Tuning Assistant

Preserve the existing Welch estimation, coherence filtering, controller reconstruction, plant identification, loop-shaping synthesis, per-iteration clamps, reviewable PID/slider proposal, MSP/CLI application paths, and two-flight convergence requirement.

The measurement basis is the closed-loop response `T(f) = setpoint -> gyro`. Unlike the Configurator's craft-agnostic fixed-target scaling, Airframe reconstructs the recorded controller and identifies a craft-specific plant before proposing gains:

1. Estimate `T(f)` with Hann-windowed Welch cross spectra, 50% overlap, magnitude-squared coherence, and rejection of bins below the validated coherence gate. Derive bandwidth, resonance, phase margin, sensitivity, and frequency-domain step response.
2. Reconstruct the recorded controller `C(f)` analytically from header PID/D Max/Feedforward values, D-term filters, and loop rate.
3. Recover loop response `L = T / (1 - T)` and plant `G = L / C` over reliable bins. Fit a coherence-weighted second-order-plus-dead-time model and publish fit quality as first-class evidence.
4. Derive achievable bandwidth and phase-margin targets from identified delay, optionally biased by explicitly selected Racing/Freestyle/Cinematic intent. Synthesize P/I/D/Feedforward through loop shaping and map the result to simplified-tuning sliders only when slider granularity can represent it safely.
5. Clamp every iteration, back off for resonance, never loosen filtering, and refuse a proposal when coherence, fit quality, saturation, or required evidence fails.

Internal delivery order:

1. Pure-Swift offline algorithm spike in `BlackboxAnalysis`, exposed through an `AirframeCLI` command that prints measurements, fit quality, limitations, and proposed sliders for a CHIRP `.bbl`.
2. Synthetic known-plant round trips plus side-by-side comparison with Configurator output on the same representative real CHIRP logs. Existing ordinary Step Response fixtures do not satisfy this gate.
3. Version-scoped MSP read/write for CHIRP and simplified-tuning parameters plus reversible CLI-diff generation.
4. Assistant UI and document-owned tuning-session state machine.
5. Convergence tracking, optional use-case targets, localization, and any separately validated Yaw strategy.

Before the offline spike, verify the exact Betaflight 2026.6 CHIRP/debug field layout against pinned firmware source and decide from evidence whether slider granularity is sufficient or per-term output is required. Yaw remains measurement-only until that separate decision is validated.

Add:

1. A passing, adequately confident Filter Score as prerequisite. It may come from a separate filter-validation flight but must match craft identity, firmware generation, motor poles, and a fingerprint of relevant filter configuration. Any later filter change invalidates it.
2. The structured capture diagnostics from Measures 2 and 9. Failed CHIRP completeness, coherence, saturation, stick isolation, or axis coverage produces guidance but no PID recommendation.
3. Tune Score Key Findings plus current/proposed controller values, modeled response, phase margin, sensitivity, expected step response, and limitations.
4. A relative noise regression guard after each gain change. Compare filtered gyro, D-term, and motor output against the session baseline; stop and recommend rollback beyond validated limits. This is not a replacement Filter Score.
5. Versioned user-owned tuning-session history in the Airframe document: settings fingerprints, accepted proposals, applied values, score versions, evidence references, and convergence. Recomputable spectra/render data stay in the derived cache. Raw logs remain session-only until placed in a document.
6. Roll/Pitch-first safety. Yaw stays measurement-only until separately validated. Never change filters or apply FC changes without explicit confirmation. Produce a reversible CLI diff and retain previous values. A filter change terminates the PID convergence sequence and requires a new baseline.

Acceptance: fingerprint mismatch blocks recommendations, MSP writes require confirmation, CLI diffs reproduce proposals, noise regression stops an iteration, convergence requires two matching flights, and document close cancels all work and releases session owners.

#### Measure 11: Future Separate Filter Tuning Assistant

Keep active filter tuning outside the CHIRP PID assistant. It becomes eligible only after Filter Score v1 is stable across representative craft, controlled configurations have been compared on the same craft, current Betaflight filter semantics are source-verified, and delay/noise/motor-output/temperature/damaged-prop validation procedures exist.

If separately approved, it changes one filter dimension per iteration, requires a new validation flight, compares against the exact previous configuration, never changes filters and PIDs in one iteration, invalidates the PID plant model after filter changes, and requires explicit review plus reversible application.

### Surgical Changes

- Implement each measure as a separate public Airframe commit after the mandatory user decision about changelog relevance. Do not bundle the roadmap into one feature branch or infer approval for a later measure from approval of an earlier one.
- Expected public `BlackboxAnalysis` interfaces are `AnalysisStepResponse.Evidence`, `AnalysisStepResponse.UnavailableReason`, extended `AnalysisStepResponse.AxisResult` metrics, `AnalysisFilterReview`, versioned `AnalysisFilterScore`, and a small deterministic `AnalysisTuningFinding` shared by score presentations.
- Later assistant phases add versioned tuning-session state, a filter-configuration fingerprint, proposed/applied configuration deltas, and evidence/convergence records.
- Calculations and thresholds belong in `BlackboxAnalysis`; header/configuration extraction in `BlackboxReader`; localized text in `AirframeCaptions`; presentation in existing Spectrum, Step Response, and Frequency Response features; FC setup/application in `MSP` and `FlightController`.
- Domain interfaces remain pure, `Sendable`, independent of SwiftUI/localization, deterministic for identical input, explicitly versioned when scored/persisted, and able to represent missing evidence without strings.
- No external dependency or upstream-reference modification is allowed.
- Bump the Step Response persistent dataset version when `AxisResult` changes. Give Filter Review its own versioned semantic cache. Cache measurements/bands/evidence, not pixels, localized text, findings, or SwiftUI state. Keys include algorithm version, log identity, selected range, signal identities, sample-rate policy, and relevant configuration fingerprint.
- All app-side work uses `ProcessingActivityCounter`. New document-scoped tasks/caches require explicit ownership, idempotent shutdown, cancellation, late-publication rejection, RAM clearing, and memory-pressure behavior.
- Measures 1-8 need no external API or Airframe document-format change. Measure 10 adds a versioned user-owned tuning-session schema; migration preserves previous settings and evidence provenance.

### Goal-Driven Execution

For every selected measure:

1. Re-read the relevant Knowledge Base claims and current Betaflight source before defining semantics or thresholds.
2. Implement only that measure and its declared prerequisite interface changes.
3. Add focused synthetic, fixture, missing-evidence, determinism, and boundary tests described above.
4. Run relevant full package suites, app-hosted tests, macOS and generic iOS Simulator builds, String Catalog validation, and `git diff --check`.
5. Verify every new SwiftUI file has a realistic production-model preview and every user-facing string is localized.
6. For new data-backed work, perform document lifecycle tests and a live repeated open/use/close pass; require idle CPU, no late analysis/cache writes, zero pending writes, released document/window/workspace/cache roots, and bounded physical footprint.
7. Use representative logs for live acceptance. Do not promote calibration-derived labels or recommendations until their specific evidence gates pass.
8. Before a public commit, obtain the user's changelog-relevance decision and follow the mandatory trailer rule. Do not commit or push merely because a measure passed verification.

Roadmap success means Airframe can progress from transparent evidence, through calibrated and explainable assessments, to reversible active assistance without presenting historical expert examples as universal rules or allowing weak evidence to produce strong tuning actions.

### Assumptions and Defaults

- Documentation, code, captions, and planning artifacts remain English.
- Filter Score uses the selected strict evidence gate and requires Roll/Pitch; Yaw remains descriptive until separately validated.
- Filter Review is broadly available while numerical Filter Score is intentionally less available.
- Tune Score v1 remains unchanged during Measures 1-5.
- No combined Tune+Filter score is introduced.
- The existing CHIRP PID Assistant algorithm is extended, not replaced, and never changes filters.
- Active Filter Tuning assistance is a separate future project and is not approved by this roadmap alone.
- This roadmap records future implementation scope. Selection and implementation of each measure remain separate user decisions.

# macOS 1.0 Release And Final iPad TestFlight Build (Approved 2026-08-11)

## Think Before Coding

- Keep the existing multiplatform app target and shared bundle identifier. Confirm build-setting ownership before editing and inspect the produced iOS bundle rather than trusting project text alone.
- Treat App Store release and TestFlight distribution as separate gates: publish macOS only and leave the iOS/iPadOS App Store platform unsubmitted.

## Simplicity First

- Use Xcode's `TARGETED_DEVICE_FAMILY = 2` app-target setting to exclude iPhone. Add no new target, bundle identifier, runtime device check, or platform fork.

## Surgical Changes

- Change only the Airframe app target's Debug, Beta, and Release device-family settings. Leave unit/UI test bundle settings and all existing iPad implementation intact.
- Pause general iOS/iPadOS development after one final iPad-only TestFlight build. Make no iPad UI improvements or macOS UI changes as part of this transition.

## Goal-Driven Execution

- Verify Debug, Beta, and Release resolve to iPad-only for iOS; build the iPad simulator app and inspect its final `UIDeviceFamily` as `[2]`.
- Build macOS Release and run proportionate existing tests. Then smoke-test the archive on physical iPad, upload it to TestFlight, verify iPad-only metadata, and distribute it only to existing testers.
- Complete only the native macOS App Store version. Keep iOS/iPadOS unpublished and disable the iPad app on Apple silicon Macs if App Store Connect exposes that option.
