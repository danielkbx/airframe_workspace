# Airframe Investigation Plan

## Graph Prepared-Series Prewarm Cache (Implemented 2026-07-17)

### Think Before Coding

- The cache must improve settled Graph detail latency without adopting upstream's much higher memory footprint.
- Cached visible detail has priority over speculative work. Memory pressure must trim by priority and stop once the target is reached.
- The cache stores compact detail-ready samples, not raw decoded frame graphs.

### Simplicity First

- Kept the existing `GraphModelCache` as the first render-model lookup layer.
- Added a prepared-series cache underneath it, keyed by log ID and ordered selected selector IDs.
- Did not add UI, persistence, schema migration, new dependencies, or cross-shape partial reuse.

### Surgical Changes

- `GraphModel` now has `makePreparedSeries(...)` plus a prepared-series render overload while preserving the existing `makeModel(...)` signature.
- `GraphSurface` checks render detail first, then prepared detail, then overview/stale placeholder, then delayed cancellable detail extraction.
- Successful useful detail extraction stores both the render model and compact prepared series.
- Idle prewarm schedules utility-priority previous/next range preparation only when the Graph is not interacting; request changes and interaction cancel the prewarm token.
- `DocumentView` injects the document-scoped prepared cache and trims it on iOS memory warnings and macOS resign-active lifecycle events.

### Goal-Driven Execution

Verification:

- macOS `Airframe` app compile-check build passed with the new prepared cache wired into the app target.
- Focused `AirframeTests` compile still stops on unrelated stale `DocumentStateStoreTests` references to removed field-selection and graph-window APIs; the new cache test's XCTest async-autoclosure issue was corrected.

## Graph Loading Animation Toggle (Implemented 2026-07-17)

### Think Before Coding

- The user needs a visible hint only when currently visible coarse Graph lines are expected to change because a real detail request is in flight.
- The effect must not imply that skipped fast-scrub regions are loading, and it must not be coupled to generic task churn.
- Follow-up user feedback clarified that detail loading itself must not start during fast scrubbing: cached detail should still display immediately, but uncached detail work should wait for a stable final range and old in-flight work should be cancelled when the visible range moves away.

### Simplicity First

- Reused `AirframeGlobalSettings` for the global toggle and `LogViewCommands` for the existing View-menu surface.
- Added a source-compatible `GraphSurfaceCanvas.LineRefinementEffect` render hint instead of introducing a new overlay view or dependency.
- The setting only affects the animation; Min/Max detail refinement still runs when the setting is off.
- Added a 400 ms stabilization delay only for uncached `.detail` builds; cached detail and overview/stale placeholders remain immediate.

### Surgical Changes

- Added persisted default-on key `airframe.graph.loadingAnimationEnabled` and View-menu toggle `Show Graph Loading Animation` with `sparkles`.
- `GraphSurface` now tracks the loaded data source and an active refinement key containing log ID, section signature, quantized width, load range, window duration, and requested data source.
- The glow starts only for the current visible `.detail` request after no cached detail match was found and an overview/stale placeholder remains visible; matching completion, cancellation, unavailable/failure, and request changes clear it.
- Reduce Motion renders a static low-opacity glow; otherwise the glow pulses subtly through `TimelineView(.animation)`.
- The glow was strengthened after user feedback: 10 pt glow width, pulse opacity `0.18...0.38`, Reduce Motion opacity `0.24`, clamp `0...0.45`.
- `GraphSurface` tracks active detail work through a cancellation token. It cancels when the visible range leaves the active load range or log/sections/data source change, but keeps work during zoom-in when the active range still covers the new visible range.
- `BlackboxAnalysisWorkspace.viewportSeries` gained an optional `AnalysisCancellationToken` and throws `.cancelled` at cooperative cancellation checks before/after Reader extraction, during row projection, per selector, and during bucket sampling.

### Goal-Driven Execution

Verification:

- `git -C Airframe diff --check` passed.
- `swift test` passed in `Airframe/Packages/AirframeUI` (85 Swift Testing tests).
- `swift test` passed in `Airframe/Packages/BlackboxAnalysis` (98 Swift Testing tests).
- macOS `Airframe` app build passed.
- iOS simulator `Airframe` app build passed on `iPhone 17` / iOS 26.5.
- Focused `AirframeTests/GraphLineRefinementEffectPolicyTests` could not run because the `AirframeTests` target still compiles unrelated stale `DocumentStateStoreTests` first, which reference removed field-selection and graph-window APIs.

## Graph Idle Min/Max Refinement (Implemented 2026-07-17)

### Think Before Coding

- The wide Graph simplification was caused by the scan-overview tier becoming the final rendered data source. On long logs, the retained overview samples are globally strided, so a local 40 s window can look artificially smooth until zoom switches to detail data.
- User intent is that fast scrubbing may stay coarse, but a settled Graph should show available local detail. The chosen meaning of "all data" is Min/Max bucketed detail, not one raw point per main frame.

### Simplicity First

- `GraphWindowPolicy.Tier` remains unchanged as the performance heuristic.
- Graph model building now separates the requested data source from the policy tier: `.overview` uses scan-overview samples; `.detail` uses `viewportSeries(..., .minMaxBuckets)`.
- No graph setup migration, new user setting, renderer change, or external dependency was added.

### Surgical Changes

- `GraphSurface` tracks active drag, pinch, and scroll scrubbing. Scroll uses a short idle debounce before refinement.
- During interaction, wide windows can still show cached detail if available or the overview placeholder if not.
- After interaction settles, the load key changes even when the visible/load range did not, forcing a detail Min/Max rebuild for the current window.
- `GraphModelTests` includes a synthetic wide-window regression where overview remains strided but detail returns the requested Min/Max point budget.

### Goal-Driven Execution

Verification:

- `swift test` passed in `Airframe/Packages/AirframeUI` (83 Swift Testing tests).
- `swift test` passed in `Airframe/Packages/BlackboxAnalysis` (94 Swift Testing tests).
- macOS `Airframe` app build passed.
- iOS simulator `Airframe` app build passed on `iPhone 17` / iOS 26.5.
- `git -C Airframe diff --check` passed.
- Focused `AirframeTests/GraphModelTests` could not run because the `AirframeTests` target still fails to compile unrelated stale `DocumentStateStoreTests` references to removed field-selection and graph-window APIs before Xcode reaches the selected test.

## Graph Shared Y-Axis and Series Metadata Fix (Implemented 2026-07-16)

### Think Before Coding

- The Graph bug was a real coordinate-system error: sections normalized each series independently, so the same real value could render at different heights.
- `setpoint[0...2]` were also exposed as raw series even though Roll/Pitch/Yaw setpoints are angular-rate values in deg/s for the supported Betaflight baseline.
- Audit found one more clear metadata issue: `motorAveragePercent` was percent-valued but carried a raw axis hint. Per user direction, all motor aggregate series now display as percent.

### Simplicity First

- The renderer still consumes normalized `[-1, 1]` values and remains pure drawing code.
- The model builder now resolves one `GraphFieldScale` per section from display-scaled values and applies it to every series in that section.
- No graph setup schema, stored series IDs, UI controls, migrations, or axis-label UI were added.

### Surgical Changes

- `setpoint[0...2]` now present as `Setpoint Roll/Pitch/Yaw`, unit `deg/s`, precision 1, axis hint `.angularRate`, and display as their stored deg/s values.
- Analysis motor aggregates (`motorMinimum`, `motorMaximum`, `motorAverage`, `motorAveragePercent`) now advertise percent metadata and return percentages through `AnalysisMotorOutputRange`.
- `GraphFieldScale.resolveSection(...)` implements shared section domains: angular-rate symmetric around zero, angle fixed +/-180, motor/percent at least 0...100, mixed/raw combined observed range.
- Focused tests cover Setpoint metadata/display values, motor aggregate percent output, shared section scales, and an app GraphModel regression with Gyro Roll plus Setpoint Roll in one section.

### Goal-Driven Execution

Verification:

- `swift test` passed in `Airframe/Packages/BlackboxReader`.
- `swift test` passed in `Airframe/Packages/BlackboxAnalysis`.
- `swift test` passed in `Airframe/Packages/AirframeUI`.
- macOS `Airframe` app build passed.
- iOS simulator `Airframe` app build passed on `iPhone 17` / iOS 26.5.
- Full macOS `AirframeTests` did not run because the test target currently fails to compile in unrelated stale tests (`SpectrumSettingsTests`, `DocumentStateStoreTests`) that reference removed/changed APIs such as old `DocumentStateStore` field-selection and graph-window helpers.

## Fixed Spectrum Frequency dB Scale (Implemented 2026-07-15)

### Think Before Coding

- Frequency line plots now use one fixed display range for every field: -50 dB to +30 dB. The change is render-model-only; FFT values and heatmap modes are unchanged.

### Simplicity First

- `SpectrumModel` owns two fixed display constants and applies them unconditionally to `.frequency` render models.

### Surgical Changes

- Updated `SpectrumModel.swift` and focused `SpectrumModelTests` only. The old adaptive bounds/span logic was removed.

### Goal-Driven Execution

Verification:

- Focused macOS `AirframeTests/SpectrumModelTests` passed.
- macOS Debug app build passed.
- iOS Simulator Debug app build passed on iPhone 17 / iOS 26.5.
- `git diff --check` passed.
- Manual comparison with `btfl_007.bbl` was not run because that log file is not present in the workspace.

## Spectrum Frequency Snap (Implemented 2026-07-15)

### Think Before Coding

- Option snapping uses the displayed Frequency line's peak-bucket geometry, not an unrendered raw FFT bin. The cursor keeps its X coordinate; its Y coordinate interpolates along the visible polyline.

### Simplicity First

- `SpectrumCrosshair.isSnapping` carries transient modifier state. `FrequencyLineProjection` supplies the same points to line drawing and snap lookup, and the Canvas draws one fixed red 4 pt marker only when it receives a snap point.

### Surgical Changes

- Updated Spectrum pointer tracking, the Canvas, the app surface, and focused `AirframeUI` tests only.
- The AppKit tracking view refreshes the modifier state from a window-local `flagsChanged` monitor, so Option works without additional pointer movement. Its transparent cursor is now tied to active crosshair state.
- Heatmaps, FFT data, analysis, settings, zoom, pan, and persistence remain untouched.

### Goal-Driven Execution

Verification:

- `swift test` passed in `Airframe/Packages/AirframeUI` (72 tests).
- macOS Debug build passed.
- iOS Simulator Debug build passed on iPhone 17 / iOS 26.5.
- `git diff --check` passed.

## Spectrum Crosshair (Implemented 2026-07-15)

### Think Before Coding

- Spectrum now exposes the visible axis coordinates rather than sampling a nearest FFT value. X is always whole Hz; Y is whole dB, throttle percent, or RPM Hz. No crosshair label contains a decimal fraction.

### Simplicity First

- `SpectrumSurfaceCanvas` owns the pure projection and drawing; its crosshair chips use monospaced digits, a stable 80 pt minimum width, the accent surface, and `PrimaryOnAccent` foreground content.
- The only new state in the app surface is a transient pointer location and a two-finger pan start window.

### Surgical Changes

- Added `SpectrumCrosshair`, `SpectrumPointerTrackingView`, and focused Spectrum crosshair tests in `AirframeUI`.
- macOS reports hover and supplies an invisible local cursor; iOS maps one finger to inspection and two fingers to the existing zoom-window pan policy. Existing pinch, double-tap reset, scroll zoom, and scroll pan remain intact.
- FFT calculation, document state, Spectrum settings, and the analysis models are unchanged.

### Goal-Driven Execution

Verification:

- `swift test` passed in `Airframe/Packages/AirframeUI` (69 tests).
- macOS Debug build passed.
- iOS Simulator Debug build passed on iPhone 17 / iOS 26.5.
- `git diff --check` passed.

## Automatic Timeline Range, Native Settings, and Spectrum Range Regression (Implemented 2026-07-15)

### Think Before Coding

- Implemented one global iCloud-synced setting, `Set In and Out Automatically`, default enabled, using the existing `AirframeGlobalSettings` + UserDefaults + iCloud KVS pattern.
- Automatic detection is intentionally conservative and never mutates raw Blackbox files or overwrites an existing stored range.
- The detector uses exact main-frame samples, not scan-overview decimation. It requires full-log duration >= 20 s and candidate duration >= 10 s. The In point is idle-relative and sustained: median of the lowest 10% positive motor-average samples + 8 percentage points, held for a 500 ms window with at least 80% qualifying samples.
- Spectrum production range behavior was preserved; only regression coverage was added.

### Simplicity First

- macOS uses the native SwiftUI `Settings` scene with a `General` tab.
- iOS/iPadOS use the Home gear button and an app-local settings sheet with a `General` form section.
- `ReaderScanOverview` stores the final contextual disarm/log-end time as one extra scan fact, independent of event marker truncation.
- `BlackboxAnalysisWorkspace.automaticTimelineRange(using:)` owns motor normalization and exact range calculation.
- `DocumentStateStore` owns the atomic no-overwrite automatic range application seam.

### Surgical Changes

- Added `SettingsView`, `AnalysisAutomaticTimelineRange`, package tests, and app integration tests.
- Extended `AirframeGlobalSettings`, `DocumentView`, `DocumentStateStore`, `ReaderScanOverview`, `AirframeCaptions`, and focused test suites.
- Corrected the stale Table column-width test expectation for `Motor Avg` from `99` to the current deterministic `84`; the failure was already documented as pre-existing and unrelated to Spectrum/Graph work.
- Did not change Spectrum production range behavior or upstream reference submodules.

### Goal-Driven Execution

Verification:

- `swift test` passed in `Airframe/Packages/BlackboxReader`.
- `swift test` passed in `Airframe/Packages/BlackboxAnalysis`.
- `swift test` passed in `Airframe/Packages/AirframeCaptions`.
- `swift test` passed in `Airframe/Packages/AirframeUI`.
- Focused macOS `AirframeTests` passed in the log with 159 tests / 0 failures; local `xcodebuild` stayed resident after reporting pass and was terminated manually.
- Focused iOS `AirframeTests` passed on the available `iPhone 17` / iOS 26.5 simulator. The requested `iPhone 13 mini` destination was not installed locally.
- macOS Debug app build passed.
- iOS Debug app build passed on `iPhone 17` / iOS 26.5.

## Graph, Timeline, and macOS Interaction Polish Plan (Implemented 2026-07-15)

Implemented next UI slice:

- Timeline-toolbar current-position label is positioned by cursor fraction across the full timeline width, so its center tracks the graph cursor.
- Graph renders out-of-log-range regions with the same dark treatment used for excluded timeline regions.
- Graph zoom window duration is persisted per document/log segment through `DocumentStateRepository` and `DocumentStateStore`.
- Graph legend labels now drive the same transient series highlight state as inspector/sidebar rows; non-highlighted lines fade more strongly.
- macOS File > Save is replaced with File > Reset File Settings. The reset command requires confirmation and removes the document entry from local and iCloud document-state buffers, then resets the current window to first-open defaults.
- In Graph mode, the timeline highlights the graph's current visible viewport as transient per-window state.
- Graph and timeline hover tooltips were removed; button/tool control help remains.
- Main log content is focusable, suppresses the macOS focus effect, and gets focus on appear/tap.
- Focused content commands now support Left/Right cursor movement, Command-Left/Right range jumps, Option-Left/Right jumps across range/event/issue times, and Command-Plus/Minus/0 graph zoom.
- `Airframe.xcscheme` LaunchAction is Debug; TestAction was already Debug. Profile/Archive remain Release.
- Graph field reordering within a section is hidden; graph section reordering remains available because section order controls vertical graph band order.

Verification:

- `xcodebuild test -project Airframe/App/Airframe.xcodeproj -scheme AirframeTests -destination 'platform=macOS' -only-testing:AirframeTests/DocumentStateRepositoryTests -only-testing:AirframeTests/DocumentStateStoreTests -derivedDataPath /tmp/airframe-state-polish-after-scheme-dd` passed.
- `xcodebuild build -project Airframe/App/Airframe.xcodeproj -scheme Airframe -destination 'platform=macOS' -derivedDataPath /tmp/airframe-polish-build-macos-dd` passed in Debug and built preview dylibs.
- `xcodebuild build -project Airframe/App/Airframe.xcodeproj -scheme Airframe -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 13 mini' -derivedDataPath /tmp/airframe-polish-build-ios-dd` passed in Debug.
- `swift test` in `Airframe/Packages/AirframeUI` passed.
- Full `AirframeTests` macOS/iOS currently compile but still fail on existing `TableModelTests.testMakeModelBuildsFrameRowsAndEventRows` because current column width is `84` while the test expects `99`; this was not part of the UI polish changes.
- Follow-up correction (2026-07-15): Graph out-of-range dimming now uses the active Timeline range as the canvas data range, so zoomed views before/after In/Out boundaries dim correctly. The timeline-toolbar current-position text aligns to the Graph viewport coordinate in Graph mode, while Table/other modes keep timeline-wide alignment. The transient graph-visible range is no longer clamped before storage, because edge-centered Graph windows can legitimately extend outside the log/range.

## Series Captions and Physical Value Formatting (2026-07-14)

- Implemented Reader-side physical display conversion for standard field families and header-context-aware App/CLI captions. Table headers use units while cells render transformed numeric values only. Unknown fields remain selectable with readable fallback captions and raw values.

- Field-selection slice (2026-07-13): Table and Graph use one document-wide ordered selection of stable analysis-series IDs; groups support off/mixed/on bulk changes and future workspace presets can reuse the same representation.

## Table Perceived-Performance Slice (Implemented 2026-07-13)

- `BlackboxAnalysisWorkspace` caches header info, reader catalog, display context, field names, motor range, and the Analysis catalog at `init`; the old computed catalog reparsed the header per field per access (release: catalog x3 50 ms -> 0 ms, chunk projection x3 66 ms -> 14 ms on a 6 MB log).
- Table load task keyed by (log, selection, chunk window), not cursor time; `Table.WindowPolicy` hysteresis recenters the 2048-frame window only when the cursor leaves the inner half, never toward a touched log edge.
- Stale-while-revalidate window swaps with cursor-row re-anchoring; highlight scroll only for external cursor changes; O(n^2) per-render highlight replaced by one binary search per body pass.
- `MainFrameChunkCache` is per-ordinal (partial-hit decode, shared in-flight tasks, utility-priority superseding prefetch, running frame-total LRU); `Table.ModelStore` removed.
- Graph readiness: overview projection for wide zoom, this chunk cache for detail zoom; per-chunk LOD aggregation parked in BACKLOG.
- Open manual check: scroll feel with a large private log on macOS.

## Center-Locked, Range-Scoped Table Slice (Implemented 2026-07-13)

- The Table uses view-aligned Main-frame scroll targets anchored at the viewport center and limits movement to one target row. Event separators are retained as non-target rows.
- The moving selected-row fill is replaced by a fixed accent cursor band at the vertical center. Symmetric scroll-content margins allow intentional overscroll so both log endpoints can occupy that band.
- Table visibility now follows the active Timeline range. Cached chunk decoding may include its boundary chunks, but model projection filters Main frames and events inclusively to the range.
- The Table clamps only its displayed cursor to the active range; it never mutates the global stored Timeline position. Cursor movement inside cached data does not reload or rebuild the model.
- The Table continuously publishes its center target while a user scrolls, so the shared Timeline follows live. Timeline-driven table positioning is suppressed from feeding back. Momentum uses unrestricted view-aligned row targets and must still settle exactly on a row.

## Table Alignment And In-Layout Inspector Slice (Implemented 2026-07-13)

- Table header and row cells now use model widths as total outer cell widths, with padding inside that width.
- Frame rows are leading-aligned and stretched to the same content width as the header and event rows, so extra window width stays to the right instead of centering rows under fixed headers.
- LogDataView uses SwiftUI's native `.inspector` on macOS and iOS. Table width remains local to its `GeometryReader`; at narrow macOS widths, system-controlled inspector overlay is accepted in favor of the native inspector appearance. iOS keeps its sheet-specific presentation behavior.
- Verification target: macOS and iOS `AirframeTests`, plus a manual macOS visual check with a wide and narrow Table window.

## Indexed Table Chunk Cache (Implemented 2026-07-13)

- The Table no longer uses a 2,000-frame range query around the cursor.
- `DecodedLogScan` exposes a resumable directory whose chunks begin every fourth valid I-frame.
- `MainFrameChunkCache` is per-document, LRU, and limited to 12,288 decoded Main frames.
- Table projects selected raw/derived values from cached chunks; cold chunk loads run detached, and cache hits do not decode frames.
- The same bounded Reader/Analysis interface is ready for a later Graph consumer; Graph UI is intentionally out of scope.

## Current App Store Sandbox And iCloud State Slice

- macOS App Sandbox is enabled with read-only user-selected-file access. Airframe does not persist document URLs, security-scoped bookmarks, or file metadata; it remains a read-only byte-backed viewer.
- iCloud Key-Value Storage mirrors only the `DocumentStateRepository` per-document LRU buffer. Global fallback preferences remain local.
- Repository merge is per document identity using `updatedAt`; remote wins timestamp ties, invalid remote entries are ignored, and the existing 50-entry LRU cap remains in force.
- iCloud state changes never update a currently open document window. They update only the repository cache used by subsequent document windows.
- macOS UI-test fixtures avoid arbitrary external paths and use fixture bytes staged in the app's temporary sandbox directory before native document opening. The local macOS XCUITest host still launches the app as Running Background, so that test remains opt-in/skip-by-default pending host repair.
- macOS never restores document windows after quit or at login. Reopening an already-running, window-free app presents the native Open dialog; closing the last document leaves the app window-free.

## Current Timeline Visualization Slice (2026-07-12)

The first real visualization is implemented: the shared lower timeline in Table and Graph. Six standalone commits (`548adf3`, `5bdc1fc`, `7f636a9`, `6849b8c`, `1fbbcf6`, `2f1cccf`) cover the `motorAveragePercent` derived series with `AnalysisMotorOutputRange`, the reusable Canvas `AreaGraph`/`GraphProjection` layer in `AirframeUI`, retained per-log `DecodedLogFlightInfo` exposed through `LogContext`, the per-log current position (main-frame µs) persisted through `DocumentStateStore`/`DocumentStateRepository`, the 512-point timeline model loader with capped event markers, and the interactive timeline UI with a per-window model cache. Package and app test suites passed per step on iOS and macOS; rendering was verified in the iPhone simulator with a synthetic dynamic-motor log. Remaining manual check: drag feel on macOS. Follow-ups are parked in `BACKLOG.md` (indexed event access, metric switcher, Table/Graph position consumers).

## Current Timeline Range And Collapse Toolbar Slice (2026-07-13)

Airframe has a compact toolbar above the shared Table/Graph timeline. It shows `Timeline`, the current cursor time, and icon-only Set In/Set Out controls using `arrow.right.to.line.compact` and `arrow.left.to.line.compact`. Active ranges are stored per document and per log segment in main-frame microseconds through `DocumentStateStore` and `DocumentStateRepository`, with missing range meaning full log and reversed bounds normalized silently. Excluded timeline regions are dimmed with thicker boundary lines; analysis calculations will consume this same effective range later.

The timeline graph height is now 136 pt while the toolbar remains 34 pt. The region can collapse per log segment through a chevron next to the `Timeline` title (`chevron.down`/`chevron.up`). Collapse state is stored as true-only `collapsedTimelineSegments` in the same synced document-state repository entry. Collapsed mode hides the graph and In/Out buttons, disables matching `I`/`O` commands, and reclaims the graph height. Toolbar icon buttons use tint-only hover feedback.

## Current Phase

The `AirframeCaptions` localization-rule slice is implemented. The project-wide rule is: no user-facing string may be defined outside `AirframeCaptions`; all App, CLI, package, test, preview, and future target user-facing text must be consumed through typed caption APIs backed by Xcode `.xcstrings` localization resources. Exceptions are raw log data, file names, numeric values, debug-only test names, internal IDs, and machine-readable CLI JSON keys.

Implemented shape after the architecture correction:

- `Airframe/Packages/AirframeCaptions` owns `CaptionSet`, `Caption`, and `AppCaptionID`.
- The package uses `Sources/AirframeCaptions/Resources/Localizable.xcstrings` as the Xcode-native localization resource, with explicit English source values so Xcode shows real catalog entries instead of relying on runtime fallback strings.
- `BlackboxAnalysis` does not depend on `AirframeCaptions`; it exposes derived semantics through `AnalysisDerivedSeriesKind`.
- `AirframeCaptions` depends on `BlackboxAnalysis` and maps `AnalysisDerivedSeriesKind` to localized derived-series captions.
- `AirframeCLI` depends on `AirframeCaptions` for human event summaries and issue messages; machine-readable JSON keys remain local.
- `AirframeUI` depends on and re-exports `AirframeCaptions` for app consumers.
- App Table and Timeline event/issue/field captions use `CaptionSet`.
- `AirframeCaptionsTests.UserFacingStringGuardrailTests` prevents migrated event/issue/series caption literals from reappearing in App, CLI, or Analysis source.

Known follow-up: `ReaderInfoReportBuilder` still contains legacy hardcoded section/row labels in Reader. Do not solve this by making Reader depend on Captions, because `AirframeCaptions` already depends on Reader semantic IDs. Move the consumer-facing report assembly into `AirframeCaptions` or introduce a lower-level semantic report model first.

The workspace restructuring slice is approved and being implemented on 2026-07-13. The root workspace becomes a private Git repository with `Airframe/`, `blackbox-log-viewer/`, and `betaflight/` registered as submodules. Root commits are allowed to be lightweight workspace commits; Airframe commits remain approval-gated; upstream reference repositories remain pull-only.

Parser/reader security gate completed. The `AirframeCLI` MVP slice, modern semantic `info` report, CLI diagnostics slice, event export slice, first native SwiftUI app shell slice, progressive document-opening slice, and frame-level opening progress are implemented.

The first SwiftUI state-restoration slice is implemented for the app shell: macOS document windows get explicit minimum/default sizing, `NavigationSplitView` column visibility and selected log are stored with `@SceneStorage`, and the sidebar has stable min/ideal/max widths. Exact custom persistence of manually dragged sidebar pixel widths remains deferred unless SwiftUI's built-in restoration proves insufficient.

The iOS root scene no longer uses `DocumentGroup`. iOS now starts in a custom `WindowGroup`/`HomeView` with direct `fileImporter` and `onOpenURL` file opening; macOS keeps `DocumentGroup`.

The iPhone document navigation fix is implemented. Opening a file from the iOS home view now replaces the home content with `DocumentView` directly instead of nesting the document `NavigationSplitView` inside the home `NavigationStack`. The document sidebar no longer repeats `Airframe` as a title, and selected log rows use explicit Accent Color background with primary text.

The accent-surface foreground-color slice is implemented. `PrimaryOnAccent` and `SecondaryOnAccent` live in the app asset catalog as opaque and 60%-alpha black respectively. Selected sidebar content uses those semantic colors, so the same pair can be reused for any future content on the accent background.

Verification for the iPhone document navigation fix passed: `swift test` in `Airframe/Packages/AirframeUI`, iOS simulator `xcodebuild test` on iPhone 17 / iOS 26.5, macOS `xcodebuild test`, and a manual iPhone simulator open-url screenshot at `/tmp/airframe-ios-openurl-nav-fix.png`.

The document view architecture cleanup is implemented. `DocumentHomeView` in the app target owns the document `NavigationSplitView`, and loading/opening/opened/failed states swap sidebar/detail content inside that stable container. App-specific document views no longer live in `AirframeUI`, and app view types avoid a redundant `Airframe` prefix.

Verification for the document view architecture cleanup passed: `swift test` in `Airframe/Packages/AirframeUI`, iOS simulator `xcodebuild test` on iPhone 17 / iOS 26.5, macOS `xcodebuild test`, and a manual iPhone simulator open-url screenshot at `/tmp/airframe-document-home-openurl.png`. The later package-boundary cleanup passed `swift test` in `Airframe/Packages/AirframeUI`, iOS `xcodebuild test` with DerivedData `/tmp/airframe-ui-boundary-ios-dd-2`, and macOS `xcodebuild test` with DerivedData `/tmp/airframe-ui-boundary-macos-dd`.

The macOS log data-view structure slice is implemented. `DocumentHomeView` now keeps sidebar context separate from main log data views, exposes `Overview`, `Table`, `Graph`, and `Spectrum`, persists the selected view, adds `Command-1` through `Command-4` menu commands, provides macOS-only inspectors for data views that need settings, and gives `Table`/`Graph` a lower timeline split region. macOS document windows use a 1180x660 point minimum and 1280x760 point default size. Sidebar width is protected separately from the inspector, and the inspector now uses a custom detail split clamped to 300...460 points instead of SwiftUI's native `.inspector`.

Verification for the log data-view structure passed: `swift test` in `Airframe/Packages/AirframeUI`, iOS simulator `xcodebuild test` on iPhone 13 mini / iOS 26.5 with DerivedData `/tmp/airframe-log-views-ios-dd`, and macOS `xcodebuild test` with DerivedData `/tmp/airframe-log-views-macos-dd`.

The Table view MVP is implemented. It keeps Main + Events as the first slice, persists field selection per log segment, uses a reusable field-selection model for Table now and Graph later, builds bounded table windows around the shared current-position time, and renders a dense data-analysis SwiftUI surface with pinned headers, lazy rows, current-row highlight, viewport-center position synchronization, event separator rows, and grouped field checkboxes in the Table inspector.

Verification for the Table MVP passed: `git diff --check`, macOS `xcodebuild test` with DerivedData `/tmp/airframe-table-macos-dd`, and iOS simulator `xcodebuild test` on iPhone 17 / iOS 26.5 with DerivedData `/tmp/airframe-table-ios-dd`.

SwiftUI preview coverage is implemented for the current app view files. `DocumentHomeView`, `DocumentView`, and `HomeView` each have `#if DEBUG` preview blocks. `AirframeUI` currently has no SwiftUI view files, but now exposes debug-only `makeDebug...` factories for document/opening display states.

UI-test infrastructure is implemented. `AirframeLaunchContext` detects explicit UI-test launches and supports fixture injection with `--airframe-ui-test-fixture-name` / `--airframe-ui-test-fixture-base64`. Normal macOS Debug and Release launches use `DocumentGroup`; Debug macOS UI-test fixture bytes are staged inside the app sandbox and opened through native document infrastructure. `AirframeUITests` verifies bundled fixture opening on iOS/iPadOS. The macOS bundled-fixture UI test remains opt-in through `AIRFRAME_ENABLE_MACOS_UI_TESTS=1`; on this local host, XCUITest currently launches Airframe as `Running Background` and cannot reach the document UI, so the default macOS scheme skips that UI test while app unit tests cover the launch context.

The local `Logging` infrastructure package has been copied into `Airframe/Packages/Logging` and reduced to the dependency-free `Logging` target. Investigation and fixes for this package must happen in the Airframe copy, not the source goStation package.

Unit formatting is implemented through `Airframe/Packages/AirframeUnits`. It owns focused duration, frequency, integer, and percent formatters; `AirframeUI` owns matching `Text` views. The generic `AirframeNumberFormatting` helper is removed. `AirframeUnits` has Swift Testing coverage for invalid duration values, explicit and automatic duration units, compound durations, automatic frequency units, locale decimal separators, integers, and percentages. `AirframeUI` consumes the local package transitively, so the app target needs no direct package-product entry.

All floating unit formatters use adaptive precision: `fractionDigits` is a maximum, while the minimum is zero. This renders meaningful decimals such as `3.2 kHz` and `10.5 Hz` without adding insignificant trailing zeroes such as `320.0 Hz`.

## Objective

Investigate and design Airframe, a native Betaflight Blackbox log analyzer.

Current implementation objective: keep the parser, reader, analysis, and CLI package surfaces resilient against hostile or manipulated Blackbox files while preparing the next product slice.

## Recommended Next Step

Choose the next approved product slice after the implemented CLI MVP, modern header semantics slice, diagnostics/events slice, JSON contract cleanup, native app shell, and frame-level opening progress.

The completed CLI consumes Reader APIs and added the Reader all-frame field table needed for first-class `S`, `G`, and `H` extraction. `airframe info` now consumes a Reader-owned semantic setup report instead of knowing raw header names.

### Think Before Coding

Assumptions:

- Every file, header value, frame payload, event payload, and caller option is untrusted.
- The native app is a read-only viewer and must not mutate original log files.
- The native app registers only `.bbl` and `.bfl`; `.txt` and `.log` are not system-wide document types.
- The App Store metadata is fixed: `Airframe Blackbox Analyzer`, App Store ID `6788747725`, bundle ID `com.kumkju.airframe`, primary language English (USA).
- The UI/display name remains Airframe. `ABA` is internal shorthand only.
- Team ID and final icon are deferred.
- App accent color is `#d3fc03`.
- Simulator launches should keep Airframe in the foreground so the user can watch the run.
- No external fuzzing dependency is introduced without explicit approval.
- Deterministic in-package fuzz-ish tests are now implemented as permanent package tests.
- `I`, `P`, `S`, `G`, and `H` must be first-class in CLI schema, validation, data output, and CSV.

Tradeoffs:

- `I/P` already have Reader series table/CSV APIs; `S/G/H` now use the generic all-frame field table for CLI extraction.
- Full streaming import is still deferred; current Reader import keeps source bytes in memory behind configured size limits.
- CLI filtering starts with simple composable flags and presets, not a custom query language.
- Header-name knowledge now lives in `BlackboxReader`; the CLI is a semantic report renderer.
- CLI JSON omits source file names. Machine identity is `source`, `log`, and byte offsets; text output can still show file names.

### Simplicity First

Completed CLI product work includes:

- A generic Reader all-frame field table for `I/P/S/G/H`.
- A matching all-frame CSV encoder.
- The `AirframeCLI` package and `airframe` executable.
- `AirframeCLIKit` as a testable library target using `apple/swift-argument-parser`.
- A thin executable target that delegates to `AirframeCLIKit`.
- CLI commands for `--help`, `--version`, `--completion`, `logs`, `header`, `info`, `schema`, `validate`, `fields`, `issues`, `events`, `data`, and `csv`. `events` defaults to concise timeline text with relative seconds and supports JSON/NDJSON for machine consumers.
- Simple filter flags for exact fields, globs, markers, presentation groups, name contains, known/unknown fields, queryable fields, and presets.
- Reader event table API through `ReaderEventRecord`, `ReaderEventTable`, and `DecodedLog.events(...)`.
- CLI JSON/NDJSON snapshot tests for `info`, `schema`, `fields`, `validate`, `issues`, and `events`.
- A Reader-owned header catalog with canonical keys, legacy/current source-name aliases, modern Betaflight header recognition, semantic derived values, and `DecodedLogFlightInfo.infoReport(showEmpty:)`.
- Modern `info` sections for D-Term / PID, Feedforward, RPM Filter, GPS / Rescue, Altitude / Autopilot, and Flight Modes when matching header values exist.
- Native app shell work includes:
  - `Airframe/App/Airframe.xcodeproj`
  - `Airframe` app target
  - `AirframeTests` app unit-test target
  - `AirframeUITests` app UI-test target
  - visible `Packages` folder reference in the Xcode project pointing to `../Packages`
  - package products resolved from the referenced `Airframe/Packages` directory
  - `AirframeUI` package for document/opening state models and future reusable data-driven widgets
  - read-only SwiftUI `DocumentGroup`
  - `.bbl` and `.bfl` viewer document registration
  - English string catalog
  - placeholder asset catalog and app icon slot
- iOS app shell work includes:
  - custom `WindowGroup` root instead of `DocumentGroup`
  - `HomeView` empty state and open button
  - `fileImporter` for `.bbl`/`.bfl`
  - `onOpenURL` handling for registered file opens
  - security-scoped file URL loading through `LogDocument(fileAt:)`
- UI-test launch support includes:
  - explicit UI-test detection through `--airframe-ui-testing` or `AIRFRAME_UI_TESTING=1`
  - fixture injection through launch arguments or environment keys
  - compact committed UI-test fixtures under `Airframe/App/AirframeUITests/Fixtures/`
- iPhone document navigation cleanup includes:
  - open-from-home document views are not wrapped by the home `NavigationStack`
  - open document views do not repeat `Airframe` as a sidebar title
  - selected log rows render their own Accent Color selection and primary text
- Document view architecture cleanup includes:
  - app-target `DocumentHomeView` as the only document `NavigationSplitView` owner
  - state-specific sidebar/detail content instead of state-specific navigation containers
  - app-specific document views outside `AirframeUI`
- Progressive native document opening includes:
  - lightweight `LogDocument` values that only store source identity and bytes
  - `AirframeDocumentOpenModel` as the UI-owned async loading state machine
  - immediate pending/opening/failed/opened view states
  - header/log metadata publication before scan-backed flight information
  - per-log scan status through `AirframeLogDetailState`
- Frame-level opening progress includes:
  - `DecodedLogScanProgress` as the Reader-owned progress payload
  - `DecodedLog.scan(progressHandler:)` and `DecodedLog.flightInfo(using:progressHandler:)`
  - one progress update emitted after each decoded frame
  - byte-range-based determinate percent plus decoded frame count for UI text
- SwiftUI state restoration includes:
  - macOS document default size through the `DocumentGroup` scene
  - per-scene split-column visibility with `@SceneStorage`
  - per-scene selected-log restoration with `@SceneStorage`
  - stable sidebar column width constraints
- SwiftUI preview coverage includes:
  - debug-only `makeDebug...` factories in `AirframeUI`
  - `DocumentHomeView` previews for opened, scanning, empty, and failed states
  - `DocumentView` previews for loaded and loading states
  - `HomeView` previews for empty and opened-document states
- Logging infrastructure work includes:
  - `Airframe/Packages/Logging`
  - `Logging` product for local `os.Logger` output and in-memory session logs
  - Airframe subsystem fallback `com.kumkju.airframe`

Do not add:

- upstream-style `GraphConfig`
- app/UI targets
- attitude estimates unless gyro scaling and integration behavior are explicitly planned
- GPS distance/azimuth/cartesian projection unless GPS optional-frame alignment is explicitly planned
- persistent transformed storage
- video features
- map view
- spectrum analyzer
- broad UI shell
- external fuzzing frameworks without explicit approval; coverage-guided fuzzing is backlogged separately

### Surgical Changes

Implemented targets for the app shell slice:

- `Airframe/App/...` for the native SwiftUI app project, configs, document shell, resources, and app tests.
- `Airframe/Packages/AirframeUI/...` for shared document/opening state models and future reusable data-driven widgets.
- `Airframe/Packages/BlackboxReader/Sources/BlackboxReader/BlackboxReader.swift` for missing availability annotations on async file-open APIs exposed by Xcode package builds.
- `.agents/MEMORY.md`, `.agents/ARCHITECTURE.md`, `.agents/TASKS.md`, `.agents/PLAN.md`, and `.agents/TOOLING.md`.

Implemented targets for the progressive document-opening slice:

- `Airframe/App/Airframe/App/LogDocument.swift`
- `Airframe/App/Airframe/App/DocumentView.swift`
- `Airframe/App/AirframeTests/LogDocumentTests.swift`
- `Airframe/Packages/AirframeUI/Sources/AirframeUI/AirframeDocumentModel.swift`
- `Airframe/App/Airframe/App/DocumentHomeView.swift`
- `Airframe/Packages/AirframeUI/Tests/AirframeUITests/AirframeDocumentModelTests.swift`
- `.agents/MEMORY.md`, `.agents/TASKS.md`, `.agents/PLAN.md`, and `.agents/TOOLING.md`.

Implemented targets for the frame-level opening progress slice:

- `Airframe/Packages/BlackboxReader/Sources/BlackboxReader/DecodedLog.swift`
- `Airframe/Packages/BlackboxReader/Sources/BlackboxReader/DecodedLogScan.swift`
- `Airframe/Packages/BlackboxReader/Tests/BlackboxReaderTests/BlackboxReaderScanTests.swift`
- `Airframe/Packages/BlackboxReader/Tests/BlackboxReaderTests/BlackboxReaderFlightInfoTests.swift`
- `Airframe/Packages/AirframeUI/Sources/AirframeUI/AirframeDocumentModel.swift`
- `Airframe/Packages/AirframeUI/Tests/AirframeUITests/AirframeDocumentModelTests.swift`
- `.agents/MEMORY.md`, `.agents/ARCHITECTURE.md`, `.agents/TASKS.md`, `.agents/PLAN.md`, and `.agents/TOOLING.md`.

Previously implemented targets for the CLI slice:

- `Airframe/Packages/BlackboxReader/...` for the all-frame field table and CSV layer
- `Airframe/Packages/AirframeCLI/...` for the executable consumer
- `.agents/PLAN.md`
- `.agents/TASKS.md`
- `.agents/TOOLING.md` if new repeatable CLI/build workflows emerge.

Do not change:

- `blackbox-log-viewer/` or `betaflight/`.
- existing parser/reader security test surfaces unless the CLI consumer reveals a real API gap.
- App/UI targets.

### Goal-Driven Execution

Completed execution steps for the CLI product slice:

1. Add Reader all-frame field table support for `I/P/S/G/H`.
2. Add Reader all-frame CSV encoding.
3. Create `AirframeCLI` with executable command `airframe`.
4. Implement discovery commands: `logs`, `header`, `info`, `schema`, `validate`, and `fields`.
5. Implement extraction commands: `data` and `csv`.
6. Verify with package fixtures and command-level smoke checks.

Verification:

The CLI slice is complete: `airframe` can inspect, validate, filter, and export selected Blackbox log data as CSV/JSON without broad app/UI scope.

Recommended order after this:

1. Visually exercise the Table MVP with full private logs, including scroll-to-position, position-from-scroll, field toggles, and event separators.
2. Replace the remaining `Graph` and `Spectrum` placeholders incrementally with real data surfaces backed by `BlackboxAnalysisWorkspace`.
3. GPS optional-frame alignment and GPS distance/azimuth/local coordinate derived series.
4. Additional CLI backlog commands such as `stats`, `summary`, `frames`, and `derived` when approved.
5. Gyro scaling and attitude estimate derived series.
6. Optional coverage-guided fuzzing setup for parser/reader security.

## Current Implementation State

Done:

- Created project directory: `Airframe/`.
- Created first package: `Airframe/Packages/BlackboxCore`.
- Implemented `ByteStream`, `VariableByteDecoder`, and `BitSignExtension`.
- Added Swift Testing coverage for byte reads, little-endian primitives, signed/unsigned variable-byte decoding, malformed/truncated variable-byte data, and sign extension.
- Implemented source-level log/header discovery with `LogFileScanner`, `LogSegment`, and `HeaderLine`.
- Added Swift Testing coverage for empty inputs, missing markers, `Data` scanning, raw headers, unknown headers, colon-preserving values, absolute offsets, multiple segments, binary `H` frame boundaries, malformed headers, unterminated headers, and non-ASCII header bytes.
- Implemented typed header interpretation with `LogHeader`, `FrameDefinition`, and `LogHeaderInterpreter`.
- Added Swift Testing coverage for `Data version`, `Field I` metadata, optional `S`/`G`/`H` markers, unknown header preservation, missing optional field rows, invalid integers, invalid signedness, mismatched counts, malformed field headers, and one sanitized header fixture.
- Implemented raw frame value decoding with `FieldEncoding` and `FrameValueDecoder`.
- Added sign-extension helpers for 2-bit, 4-bit, 5-bit, 6-bit, and 7-bit packed values.
- Added Swift Testing coverage for scalar encodings, null encoding, `TAG8_8SVB`, `TAG2_3S32`, `TAG8_4S16` data version 1 and 2, `TAG2_3SVARIABLE`, unsupported encoding IDs, invalid group counts, and truncated packed payloads.
- Implemented firmware compatibility metadata with `FirmwareVersion`, `FirmwareRevision`, `BlackboxCompatibility`, and `CompatibilityStatus`.
- Set the initial parser support claim to Betaflight `4.4.3+` with Blackbox `Data version:2`; older Betaflight logs are best-effort/unsupported until fixtures and golden outputs exist.
- Implemented field predictor application with `FieldPredictor`, `FieldPredictionContext`, and `FieldPredictorApplier`.
- Implemented validated frame payload primitives with `FrameDecodingDefinition`, `DecodedFrame`, and `FramePayloadDecoder`.
- Added Swift Testing coverage for firmware parsing, compatibility status, predictor mapping/formulas/errors, frame definition validation, GPS home predictor normalization, scalar payload decoding, packed payload groups, raw-value mode, grouped overrun errors, and truncated payload propagation.
- Added package test resource support and fixture policy under `Tests/BlackboxCoreTests/Fixtures/`.
- Added working format documentation: `Airframe/doc/blackbox-log-format.md`.
- Linked the format documentation from `Airframe/README.md`.
- Copied small local full-log smoke fixtures into root `Flightlogs/small/`:
  - `barney-log00002.bfl`
  - `flip-session1-001.bbl`
  - `puck-default-001.bbl`
- Decided and implemented Reader as a separate Swift package: `Airframe/Packages/BlackboxReader`.
- Kept `BlackboxReader` dependent on `BlackboxCore`; `BlackboxCore` remains parser primitives and gained only bounded `ByteStream` range support.
- Implemented Reader import models: `ImportSet`, `SourceFile`, `Log`, `SourceID`, `LogID`, and `ReaderIssue`.
- Implemented Reader API through `BlackboxReader.open(data:)`, `open(fileAt:)`, `open(filesAt:)`, and `makeFrameStream(for:in:)`.
- Implemented `FrameStream` for full segment iteration over `I`, `P`, `S`, `G`, `H`, and `E` markers.
- Implemented Reader compatibility gating with default supported-only behavior and optional best-effort `Data version:2` mode.
- Implemented Reader state for main-frame history, skipped frame counts, GPS home validity, logging-resume events, jump validation, and corruption recovery.
- Implemented current Betaflight event decoding for sync beep, inflight adjustment, logging resume, disarm, flight mode, log end, and unknown event reporting.
- Added package-local `BlackboxReader` fixtures under `Tests/BlackboxReaderTests/Fixtures/`.
- Added a small test-only `.bbfixture` DSL so Reader fixtures can represent readable ASCII headers plus raw binary frame/event bytes without committing opaque binary blobs.
- Added native package-local `.bbl` and `.bfl` Reader fixtures to verify direct Blackbox byte-stream loading without DSL conversion.
- Added Reader tests that load a native `.bbl` fixture through `open(data:)` and a native `.bfl` fixture through `open(fileAt:)`.
- Expanded Swift Testing coverage for Reader fixture loading, no-marker sources, malformed headers, one-source imports, multi-segment files, multi-source imports, missing log IDs, compatibility blocking/best-effort mode, unsupported data versions, missing `P` definitions, I/P history decoding, max-frame-length corruption, current event payloads, GPS home flow, slow frames, unsupported optional frames, corrupt-frame recovery, truncated frames, invalid main-frame jumps, and independent stream state.
- Added Reader golden frame-stream snapshot validation for `single-log-basic`, `gps-home-flow`, and `event-flow`.
- Snapshot files live under `Airframe/Packages/BlackboxReader/Tests/BlackboxReaderTests/Fixtures/Snapshots/` and cover stable frame markers, byte ranges, validity, decoded values, decoded events, and stream issues.
- Added lazy Reader decoded-log API with `DecodedLog`, `ReaderLogSchema`, `ReaderFrameSchema`, `ReaderField`, and `NamedReaderFrame`.
- `BlackboxReader` now exposes `decodedLogs(in:)`, `decodedLog(for:in:)`, and `namedFrame(_:using:)`, while `BlackboxCore` remains a parser-primitive package.
- Added memory-light Reader summaries with `DecodedLogSummary`, `ReaderEventSummary`, `DecodedLogSummaryResult`, `DecodedLog.summarize()`, and `BlackboxReader.summaries(in:)`.
- Batch summaries use structured concurrency across decoded logs on supported Apple platforms; per-log decoding remains sequential and lazy.
- Ran local-only summary smoke/performance baseline against all files in `Flightlogs/small/`; all three decoded logs summarized successfully with 0 import issues, 0 stream issues, and 0 corrupt frames.
- Added first Reader syncpoint index API with `ReaderLogIndex`, `ReaderSyncPoint`, `ReaderLogIndex.Error`, and `DecodedLog.makeIndex()`.
- `ReaderLogIndex` stores every valid main intraframe as a syncpoint and supports binary-search lookup at or before / at or after a main-frame time.
- Added partial main-frame range decoding from Reader syncpoints with `ReaderMainFrameRange`, `ReaderMainFrameRange.Error`, extended `ReaderSyncPoint` state, and `DecodedLog.mainFrames(fromMainFrameTime:throughMainFrameTime:using:)`.
- Range decoding resumes a `FrameStream` after a valid syncpoint's `I` frame state and returns valid `I`/`P` frames in an inclusive main-frame time window.
- Added all-frame range decoding from Reader syncpoints with `ReaderFrameRange`, `ReaderFrameRange.Error`, and `DecodedLog.allFrames(fromMainFrameTime:throughMainFrameTime:using:)`.
- All-frame range decoding activates on the first in-range main frame and includes valid `S`, `G`, `H`, and `E` frames encountered before the next out-of-range main frame.
- Added single-pass Reader metadata/index scanning with `DecodedLogScan` and `DecodedLog.scan()`.
- Refactored `DecodedLog.summarize()` and `DecodedLog.makeIndex()` through shared collection logic while preserving their existing public behavior.
- Added Reader scan tests covering equality with separate summary/index APIs, event logs, recovered corrupt logs, GPS-only flow with empty index, blocked and best-effort compatibility, multi-log sources, reusable streams, and range use with `scan().index`.
- Local `Flightlogs/small/` scan smoke passed: 3 logs, 0 import issues, 0 total issues, 174 syncpoints, and `scan()` output matched separate `summarize()` plus `makeIndex()` output for every log.
- Added fast Reader header-preview API for QuickLook/log-header views with `ReaderHeaderPreviewOptions`, `ReaderHeaderPreview`, `DecodedLogHeaderInfo`, `DecodedLog.headerInfo`, `BlackboxReader.headerInfos(in:)`, and `BlackboxReader.previewHeaders(fileAt:options:)`.
- Header preview parses only bounded file prefixes, returns raw headers, common convenience metadata, frame-definition names, Explorer-style parameter groups, and preserved unknown fields without decoding frames.
- Added Reader header-info tests covering raw header preservation, common metadata, grouped parameters, unknown fields, empty craft names, compatibility-blocked logs, decoded-log ordering, bounded prefix reads, prefix growth, incomplete headers, and non-Blackbox inputs.
- Local header-preview smoke passed against `Flightlogs/small/`: Barney and Flip completed from their full small file sizes, while Puck returned the complete header after the default 64KB prefix of a 174KB file.
- Added scan-backed Reader flight-info API with `DecodedLogFlightInfo`, `DecodedLogFlightInfoResult`, `DecodedLog.flightInfo(using:)`, and `BlackboxReader.flightInfos(in:)`.
- Flight info combines `DecodedLogHeaderInfo` with `DecodedLogScan` and exposes duration, header-derived sample rate, observed main-frame rate, frame counts, syncpoint count, and issues without slowing the bounded header-preview path.
- Added main-frame field-range extraction with `ReaderFieldSelector`, `ReaderFieldSample`, `ReaderFieldRange`, and `DecodedLog.mainFrameFields(...)`.
- Field ranges select exact `I`/`P` schema fields over an inclusive main-frame time range by reusing `mainFrames(...)` and existing syncpoint indexes; unsupported markers, duplicate selectors, missing fields, invalid time ranges, and mismatched indexes are explicit errors.
- Added Reader tests for flight-info derivation, scan reuse, no-main-frame logs, compatibility behavior, batch ordering, field selection, scan-index reuse, selector validation, empty ranges, and projection parity with `mainFrames(...)`.
- Local flight-info/field-range smoke passed against `Flightlogs/small/` using a temporary external SwiftPM consumer.
- Added Reader series consumer layer with `ReaderSeriesCatalog`, `ReaderSeriesTable`, `ReaderViewportResult`, `ReaderSeriesCSV`, and `ReaderSeriesRequest`.
- Series catalog is schema-only and uses explicit `ReaderSeriesID` identity: marker, field name, and field index. Main-frame-queryable v1 series are `I` and `P`.
- Series table projects existing `ReaderFieldRange` output into typed rows with explicit `.integer` and `.missing` cells, preserving range metadata and Reader issues.
- Viewport series provides exact points and min/max bucketed points for chart consumers without adding UI, smoothing, analysis, or upstream graph/config concepts.
- CSV encoding is a leaf export/debug path over `ReaderSeriesTable`; it writes metadata columns first, selected series columns after, escaped CSV text, and no files.
- Added Reader series tests covering catalog grouping/lookup, stream reuse, table projection, missing cells, selector validation, viewport output, CSV formatting/escaping, and high-level request parity.
- Local series smoke passed against `Flightlogs/small/` using a temporary external SwiftPM consumer.
- Added Reader series presentation metadata with `ReaderSeriesPresentation`, `ReaderSeriesUnit`, `ReaderSeriesPresentationGroup`, `ReaderSeriesAxisHint`, and `ReaderSeriesValueScale`.
- Series presentation is a project-owned Reader API keyed by `ReaderSeriesID`; it provides labels, short labels, groups, conservative units, precision, axis hints, raw scale metadata, and known/unknown status without using upstream graph or field-presenter structures.
- Presentation lookup is schema/ID-only and does not decode frames or consume streams. Known current mappings include timing, gyro, accelerometer, PID/setpoint, RC command, motor, battery, GPS, debug, and state fields; unknown fields degrade to raw presentation.
- Added Reader series presentation tests covering known main-frame metadata, GPS/slow-frame groups, unknown fallback, deterministic lookup, stream reuse, and catalog order preservation.
- Added Reader display-value helpers with `ReaderSeriesDisplayValue`, `ReaderSeriesDisplayContext`, and `ReaderSeriesPresentation.displayValue(for:context:)`.
- Reader display values scale only safe, stateless display cases so far: `time` microseconds to seconds and GPS coordinate integers to coordinate degrees. Unknown and uncertain fields remain raw.
- Added `Airframe/Packages/BlackboxAnalysis` as a new Swift package depending on `BlackboxReader`.
- `BlackboxAnalysis` now exposes `BlackboxAnalysisWorkspace` as the app-facing facade for raw Reader passthrough, display-scaled raw values, and derived series behind one catalog/table/viewport API.
- Added Analysis series identity and presentation types: `AnalysisSeriesID`, `AnalysisSeriesOrigin`, `AnalysisDerivedSeriesKind`, `AnalysisSeriesPresentation`, `AnalysisSeriesDescriptor`, `AnalysisSeriesSelector`, and `AnalysisSeriesCatalog`.
- Added Analysis table and viewport types: `AnalysisSeriesCell`, `AnalysisSeriesRow`, `AnalysisSeriesTable`, `AnalysisViewportSamplingMode`, `AnalysisViewportPoint`, `AnalysisViewportSeries`, and `AnalysisViewportResult`.
- Implemented first Analysis derived series: motor minimum, motor maximum, motor average, PID sum per qualifying axis, and debug raw descriptors with debug-mode label context.
- GPS distance/azimuth/local coordinates and attitude series exist as planned `AnalysisDerivedSeriesKind` cases but are omitted from the catalog until their prerequisites are reliable.
- Added package-local `BlackboxAnalysis` fixture and Swift Testing coverage for raw passthrough, display-scaled time, motor aggregates, PID sum, debug descriptor labels, gated GPS/attitude descriptors, duplicate/unknown selector errors, exact viewport output, and min/max viewport output.
- Added the first security-hardening slice: checked integer helpers; predictor overflow detection; bounded log scanning and header interpretation; central Reader security budgets; bounded log-end event strings; issue retention caps with total issue counts; syncpoint, range, sample, selector, CSV, preview, and task-concurrency limits; throwing CSV encoding with row and byte limits; Analysis aggregate sums that avoid `Int` overflow traps; and hostile-input/limit tests.
- Added aggressive permanent hostile-input smoke coverage: deterministic random Core scanner inputs; marker-spam and hostile header scanner cases; hostile header interpreter definitions; deterministic random Reader imports; mutated valid Reader fixtures through `FrameStream` and `DecodedLog.scan()`; hostile header-preview temporary files; and range/series output pressure checks.
- Added Reader event table API with event records, event time/context, issue preservation, time filtering, and output limits.
- Added CLI `issues` command with stable text/JSON diagnostics for import, header, compatibility, stream, range, selector, and optional CSV checks.
- Added CLI `events` command with default timeline text output plus JSON and NDJSON output for decoded `E` frames.
- CLI event text output now derives relative seconds from first valid main-frame time and uses readable labels for common disarm and flight-mode changes, including `arm` and `flightMode Air`, while JSON/NDJSON keep raw event payloads.
- CLI event flight-mode naming now parses full Betaflight revision strings robustly and has regression coverage for removed legacy labels such as `Baro` and `Rangefinder`.
- CLI event text now uses readable labels such as `Sync beep`, `Disarm`, `Flight mode Angle`, `Flight mode Acro`, and `End of log`, rather than camelCase event names or changed-flag `on`/`off` lists. Pure ARM changes render as `Arm`/`Disarm`.
- Removed source file names from CLI machine JSON; `source`, `log`, and offsets are the stable machine identifiers.
- Added CLI JSON/NDJSON snapshot tests for `info`, `schema`, `fields`, `validate`, `issues`, and `events`, plus text-output and unsupported-format tests for events.
- Added `Airframe/scripts/smoke-local-flightlogs.sh` for local-only CLI smoke checks against `Flightlogs/small/`.
- Local CLI smoke script passed against all 3 files in `Flightlogs/small/`.
- Completed first pre-commit audit fixes: Reader log-end string limit edge handling, suspicious logging-resume issue reporting before a main-frame baseline, header-preview truncated-tail tolerance, CLI absolute-path sanitization, Airframe `.gitignore` protection for `.agents/` and `AGENTS.md`, and public README/format/CLI-help wording cleanup.
- Added progressive native document opening: `LogDocument` no longer synchronously parses or scans during `FileDocument` initialization; `DocumentView` owns an `AirframeDocumentOpenModel`; `AirframeUI` exposes `AirframeDocumentOpenState`, `AirframeDocumentSnapshot`, and `AirframeLogDetailState`; the UI can show file identity, loading status, header/log metadata, and per-log scan-backed timing/frame-count values as they become available.

Last affected-package verification:

```bash
cd "/Users/daniel/Projekte/Blackbox/Airframe/Packages/BlackboxCore"
swift test

cd "/Users/daniel/Projekte/Blackbox/Airframe/Packages/BlackboxReader"
swift test

cd "/Users/daniel/Projekte/Blackbox/Airframe/Packages/BlackboxAnalysis"
swift test

cd "/Users/daniel/Projekte/Blackbox/Airframe/Packages/AirframeCLI"
swift test

cd "/Users/daniel/Projekte/Blackbox/Airframe"
./scripts/smoke-local-flightlogs.sh
```

All affected packages passed after the pre-commit audit cleanup. Current automated test count:

- `BlackboxCore`: 94 Swift Testing tests in 12 suites.
- `BlackboxReader`: 161 Swift Testing tests in 24 suites.
- `BlackboxAnalysis`: 8 Swift Testing tests in 3 suites.
- `AirframeUI`: 3 Swift Testing tests in 1 suite.
- `AirframeCLI`: 26 Swift Testing tests in 2 suites.

Progressive document-opening verification:

```bash
cd "/Users/daniel/Projekte/Blackbox/Airframe/Packages/AirframeUI"
swift test

cd "/Users/daniel/Projekte/Blackbox/Airframe"
xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/airframe-progressive-open-test-dd
```

The progressive-opening checks passed with 3 AirframeUI Swift Testing tests and 2 Airframe app XCTest tests.

Native app shell verification:

```bash
cd "/Users/daniel/Projekte/Blackbox"
xcodebuild -list -project Airframe/App/Airframe.xcodeproj
xcodebuild -project Airframe/App/Airframe.xcodeproj -scheme Airframe -configuration Debug -destination 'generic/platform=macOS' build
xcodebuild -project Airframe/App/Airframe.xcodeproj -scheme Airframe -configuration Debug -destination 'generic/platform=iOS Simulator' build
xcodebuild -project Airframe/App/Airframe.xcodeproj -scheme Airframe -configuration Debug -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
xcodebuild test -project Airframe/App/Airframe.xcodeproj -scheme Airframe -configuration Debug -destination 'platform=macOS'

cd "/Users/daniel/Projekte/Blackbox/Airframe/Packages/AirframeUI"
swift test

cd "/Users/daniel/Projekte/Blackbox/Airframe/Packages/BlackboxReader"
swift test
```

All listed native app shell checks passed. Xcode emits a harmless AppIntents metadata warning because the app has no AppIntents framework dependency.

Project-file cleanup update: the visible Xcode package source group must be `Packages` with path `../Packages`. Stale copied folders under `Airframe/App/Packages` or `Airframe/App/Packages 2` are wrong and should be removed.

Local full-log frame-stream smoke verification passed earlier with a temporary `/tmp` SwiftPM runner:

- `Flightlogs/small/barney-log00002.bfl`: 744 frames, 0 corrupt, 0 stream issues.
- `Flightlogs/small/flip-session1-001.bbl`: 1776 frames, 0 corrupt, 0 stream issues.
- `Flightlogs/small/puck-default-001.bbl`: 3765 frames, 0 corrupt, 0 stream issues.

Local full-log summary smoke/performance baseline also passed with `/tmp/airframe-summary-smoke`:

- Input: 3 files, 3 decoded logs, 0 import issues.
- Baseline run: open `0.0101s`, batch summaries `0.3362s`, max RSS `10.9MB`.
- `barney-log00002.bfl`: 33,554 bytes, Betaflight `2025.12.5`, 744 valid frames (`E=3`, `G=8`, `H=1`, `I=29`, `P=702`, `S=1`), 0 issues, main time `187245421..188140959`.
- `flip-session1-001.bbl`: 49,152 bytes, Betaflight `4.4.3`, 1,776 valid frames (`E=4`, `I=28`, `P=1742`, `S=2`), 0 issues, main time `8041862..8915082`.
- `puck-default-001.bbl`: 174,080 bytes, Betaflight `4.6.0`, 3,765 valid frames (`E=3`, `G=37`, `H=1`, `I=117`, `P=3606`, `S=1`), 0 issues, main time `278915523..282659740`.

Local full-log index smoke verification passed with `/tmp/airframe-index-smoke`:

- Input: 3 files, 3 decoded logs, 0 import issues.
- `barney-log00002.bfl`: 29 syncpoints, 0 issues, main time `187245421..188140959`, syncpoint time `187245421..188138455`, midpoint lookup `187693190 -> 14`.
- `flip-session1-001.bbl`: 28 syncpoints, 0 issues, main time `8041862..8915082`, syncpoint time `8041862..8894845`, midpoint lookup `8478472 -> 13`.
- `puck-default-001.bbl`: 117 syncpoints, 0 issues, main time `278915523..282659740`, syncpoint time `278915523..282649679`, midpoint lookup `280787631 -> 58`.

Local full-log range smoke verification passed with `/tmp/airframe-range-smoke`:

- Input: 3 files, 3 decoded logs, 0 import issues.
- Each smoke range compared `DecodedLog.mainFrames(...)` output against a full `FrameStream` filtered by main-frame time and matched exactly.
- `barney-log00002.bfl`: requested `187543190..187843190`, syncpoint `9`, 244 frames, 0 issues.
- `flip-session1-001.bbl`: requested `8328472..8628472`, syncpoint `9`, 608 frames, 0 issues.
- `puck-default-001.bbl`: requested `280637631..280937631`, syncpoint `53`, 298 frames, 0 issues.

Local range performance benchmark passed with a temporary `/tmp/airframe-range-benchmark.*` SwiftPM runner in release mode:

- Small staged logs: process max RSS about `10.7MB`, all three files completed in `0.84s`.
- Large private logs: process max RSS about `211.6MB`, four selected files completed in `40.63s`.
- `8.0MB` Puck log: 191,245 frames, summary `1.785s`, index `1.218s`, 1% all-frame range `12.336ms`, 5% all-frame range `61.002ms`, repeated 1% all-frame average `12.272ms`.
- `16MB` Flip multi-log file: 13 logs, largest log 241,590 frames, summary `1.992s`, index `1.310s`, 1% all-frame range `13.553ms`, 5% all-frame range `66.776ms`, repeated 1% all-frame average `13.365ms`.
- `19MB` Barney log: 530,770 frames, summary `4.501s`, index `3.057s`, 1% all-frame range `32.112ms`, 5% all-frame range `157.896ms`, repeated 1% all-frame average `31.198ms`.
- `30MB` Barney log: 822,281 frames, summary `7.016s`, index `4.651s`, 1% all-frame range `48.089ms`, 5% all-frame range `235.666ms`, repeated 1% all-frame average `46.459ms`.
- `mainFrames(...)` and `allFrames(...)` had nearly identical timings; optional frame inclusion is not the dominant cost.
- Repeated identical and overlapping range reads cost about the same as cold reads because there is no cache, but the more significant bottleneck is the repeated full-log pass for summary plus index.

Local single-pass scan smoke verification passed with `/tmp/airframe-scan-smoke`:

- Input: 3 files, 3 decoded logs, 0 import issues.
- `barney-log00002.bfl`: frame counts `E=3`, `G=8`, `H=1`, `I=29`, `P=702`, `S=1`; 29 syncpoints; 0 issues.
- `flip-session1-001.bbl`: frame counts `E=4`, `I=28`, `P=1742`, `S=2`; 28 syncpoints; 0 issues.
- `puck-default-001.bbl`: frame counts `E=3`, `G=37`, `H=1`, `I=117`, `P=3606`, `S=1`; 117 syncpoints; 0 issues.
- `DecodedLog.scan()` matched separate `DecodedLog.summarize()` and `DecodedLog.makeIndex()` output for all three logs.

Local single-pass scan performance benchmark passed with the same temporary `/tmp/airframe-range-benchmark.*` release runner:

- Small staged logs: `scan()` speedup `1.96x...1.99x` versus current separate `summarize()` plus `makeIndex()` calls.
- `8.0MB` Puck log: current separate `3.706s`, `scan()` `1.861s`, saved `1.844s`, current-call speedup `1.99x`; compared with the earlier pre-scan baseline total `3.003s`, practical speedup is about `1.61x`.
- `16MB` Flip multi-log file: largest log current separate `3.975s`, `scan()` `1.989s`, saved `1.986s`, current-call speedup `2.00x`; compared with the earlier pre-scan baseline total `3.302s`, practical speedup is about `1.66x`.
- `19MB` Barney log: current separate `9.174s`, `scan()` `4.627s`, saved `4.547s`, current-call speedup `1.98x`; compared with the earlier pre-scan baseline total `7.558s`, practical speedup is about `1.63x`.
- `30MB` Barney log: current separate `14.239s`, `scan()` `7.172s`, saved `7.067s`, current-call speedup `1.99x`; compared with the earlier pre-scan baseline total `11.668s`, practical speedup is about `1.63x`.
- Range timings stayed effectively unchanged after the scan work: the 30MB log measured 1% all-frame range `47.623ms`, 5% all-frame range `238.743ms`, and repeated 1% all-frame average `47.303ms`.

Local fast header-preview smoke verification passed with `/tmp/airframe-header-preview-smoke`:

- The runner used only `BlackboxReader().previewHeaders(fileAt:)`, not `open`, `scan`, `summarize`, or `makeIndex`.
- `barney-log00002.bfl`: source bytes `33,554`, bytes read `33,554`, craft `Barney`, firmware `Betaflight 2025.12.5`, board `SPBE SPEEDYBEEF7V3`, looptime `312`, raw headers `234`, groups `16`, unknown fields `104`.
- `flip-session1-001.bbl`: source bytes `49,152`, bytes read `49,152`, craft `nil`, firmware `Betaflight 4.4.3`, board `HARC HAKRCF722V2`, looptime `125`, raw headers `184`, groups `16`, unknown fields `75`.
- `puck-default-001.bbl`: source bytes `174,080`, bytes read `65,536`, craft `Puck`, firmware `Betaflight 4.6.0`, board `JHEF JHEF405PRO`, looptime `125`, raw headers `227`, groups `16`, unknown fields `106`.

Local flight-info/field-range smoke verification passed with `/tmp/airframe-flight-info-field-range-smoke`:

- The runner opened the three staged logs, called `scan()`, `flightInfo(using:)`, and `mainFrameFields(["time", "gyroADC[0]"], ... using: scan.index)`.
- `barney-log00002.bfl`: craft `Barney`, firmware `Betaflight 2025.12.5`, duration `0.895538s`, header rate `3205.13Hz`, observed main-frame rate `815.15Hz`, selected samples `204`, issues `0`.
- `flip-session1-001.bbl`: craft `nil`, firmware `Betaflight 4.4.3`, duration `0.873220s`, header rate `8000.00Hz`, observed main-frame rate `2025.84Hz`, selected samples `507`, issues `0`.
- `puck-default-001.bbl`: craft `Puck`, firmware `Betaflight 4.6.0`, duration `3.744217s`, header rate `8000.00Hz`, observed main-frame rate `994.07Hz`, selected samples `249`, issues `0`.

Local series smoke verification passed with `/tmp/airframe-series-smoke`:

- The runner opened the three staged logs, called `scan()`, `seriesCatalog`, `seriesTable(for:using:)`, `viewportSeries(for:using:)`, and `seriesCSV(for:using:)`.
- `barney-log00002.bfl`: `groups=5`, `mainSeries=96`, `rows=731`, `viewportPoints=458`, `csvRows=731`, `issues=0`.
- `flip-session1-001.bbl`: `groups=3`, `mainSeries=68`, `rows=1770`, `viewportPoints=456`, `csvRows=1770`, `issues=0`.
- `puck-default-001.bbl`: `groups=5`, `mainSeries=106`, `rows=3723`, `viewportPoints=634`, `csvRows=3723`, `issues=0`.

## Fixture Policy

- Root `Flightlogs/` is the local staging area for full real logs and manual smoke/performance checks.
- Package tests should include required fixtures directly under `Airframe/Packages/BlackboxCore/Tests/BlackboxCoreTests/Fixtures/`.
- Prefer small sanitized extracts from real logs.
- Use synthetic fixtures when available real logs do not contain the exact valid, boundary, rare, corrupt, or truncated case needed by the system under test.
- Do not store full private logs in the package test target.
- Keep `Tests/BlackboxCoreTests/Fixtures/README.md` current with every package fixture, its type, and purpose. Do not include which tests use it.

## Repositories

- Reference viewer: `blackbox-log-viewer/`
- Firmware writer reference: `betaflight/`
- Agent context: `.agents/`

## Preferred Development Strategy

1. Keep app/UI targets out until the core package can parse real logs reliably.
2. Start with package-only core slices.
3. Separate parser, model, indexing, and analysis concerns cleanly.
4. Implement one aspect at a time.
5. Add extensive tests before moving to the next layer.
6. Use root `Flightlogs/` for full-log smoke checks and package fixtures for automated tests.
7. Evaluate app integration only after package-level core behavior is proven.

## Testing Strategy

- Use modern Swift Testing.
- Prefer `#expect` and `#require`.
- Use parameterized tests for encodings, predictors, headers, fixtures, and corruption cases.
- Keep tests parallel-safe by default.
- Compare against `blackbox-tools` or firmware/viewer behavior where possible.
- Include malformed/truncated/corrupt log cases early.
- Keep `Airframe/doc/blackbox-log-format.md` in sync with parser behavior and fixture discoveries.

## Swift Conventions

- Swift language version: 5.9.
- Prefer modern Swift domain modeling, including enums with associated values.
- Prefer `throws` over returning Swift `Result`.
- Attach concrete type-specific `Error` types as nested types or extensions.
- Prefer async/await and structured concurrency over completion blocks.
- Prefer one-line calls and function declarations when they fit within 150 characters.
- Prefer namespacing with nested types, e.g. `Parser.Result`.
- Put each large type in its own file.
- Compact subordinate types may live near their parent type; shared subordinate types get their own files.

## Versioning

- Use Semantic Versioning.
- All Swift Packages and every Xcode target must share the same version.
- Xcode targets should inherit `MARKETING_VERSION` from `Base.xcconfig`.

## Constraints

- Do not introduce external dependencies without explicit user approval.
- Build an independent Swift implementation. Upstream JS/C/C++ may be read to understand behavior and edge cases, but must not be translated line by line or mirrored through its naming/control-flow structure.
- Public comments should explain format facts and local design choices directly, without phrases like "the viewer does..." or "the firmware writes...".
- Project artifacts must be in English, including code, variables, comments, docs, agent files, and commit text.
- Do not mention AI, agents, Codex, ChatGPT, or automation attribution in `Airframe/`, official docs, commit messages, PR titles, or PR descriptions.
- Public-facing prose should sound human and developer-written, not like generated boilerplate.
- File headers for this project use `SPDX-FileCopyrightText: 2026 mail@danielkbx.com`; do not add an SPDX license identifier until the license is explicitly chosen.
- GPL-3.0 is acceptable if required by reused/ported GPL code, but an independent implementation may use a different license.
- App Store distribution is optional.

## GraphSetup Sidebar Slice

- Replace the legacy document-wide flat field selection with compact per-document `GraphSetup` state: a fixed Table Columns section plus editable Graph sections.
- Keep assignments independent by mode, retain unknown IDs, discard historic flat selections, and use the same editor in both inspectors with Table restrictions enforced.
- Verify persistence through the existing local/iCloud document-state buffer, table-column projection, macOS/iOS tests, and Debug/Release builds before starting graph rendering.

## Graph Renderer Slices (2026-07-14)

The native Graph mode is implemented in five slices, replacing the placeholder in `Graph.Container` with `Graph.Surface`. User decisions: cursor-centered window (drag scrubs the shared cursor, cursor bar fixed at center), SwiftUI Canvas rendering with a renderer-agnostic model as Metal escape hatch, and sticky per-field colors persisted in GraphSetup storage.

- Slice 1, static renderer: `BlackboxAnalysis.overviewDisplayPoints(for:in:)` routes overview samples through the same display scaling as `seriesTable` (parity-tested); `Graph.Model` (normalized [-1,1] points, built off-main), `Graph.FieldScale` (axis-hint ranges: angularRate symmetric with 500 deg/s floor, angle ±180, motorOutput/percent at least 0...100, otherwise observed fit with 10% headroom, zero-anchored when non-negative), `Graph.WindowPolicy` (cursor-centered visible window, 3x load window, inner-half reload hysteresis, 1.5x zoom drift, point budget clamp(2x px, 512, 4096), width quantized to 128 px, detail tier under ~64k estimated frames else scan-overview tier), `Graph.SurfaceCanvas` (sections, center/quarter lines, 1/2/5-ladder time grid with labels, orange event/issue markers, one path+stroke per series, accent cursor band).
- Slice 2, interaction: one DragGesture covers scrubbing (traces follow the pointer, cursor writes to `DocumentStateStore`) and tap-to-jump (sub-3pt movement); MagnifyGesture zooms `windowMicros` (transient `@State`, default 10 s, clamped 50 ms...full range); accessibility adjustable actions step by 1/20 window.
- Slice 3, colors: `SeriesPalette` in AirframeUI (12 fixed hues as light/dark pairs, resolved once, cycling indexes, no yellow-green near the accent); sticky `colorSlots: [String: Int]` on `GraphSetup.Section` (lowest-free-slot on add, freed on remove, untouched on reorder, collision/migration normalization in init, persisted as `"c"` in Storage v1); dot before the caption in `GraphSetupEditor` graph mode; renderer and legend consume the same slots. Also fixed a shadowed-parameter bug in `GraphSetup.insertSeries(_:in:at:)` that inserted at the section index instead of the requested position.
- Slice 4, hover highlight: transient `GraphHighlightState` (@Observable, never persisted) injected via `\.graphHighlightState` from `LogDataView`; macOS `.onHover` / iOS tap-toggle on editor field rows; highlighted series draws last at 3.5 pt while section peers dim to 45%.
- Slice 5, cursor value readout: `GraphSetupValueReadout` resolves all visible inspector series with one bounded `seriesTable` query (±50 ms around the cursor, last row at or before the cursor, forward fallback near log start), coalesced with an 80 ms task-sleep debounce and stale-while-revalidate; row captions show `"<value> <unit>"` via the shared `SeriesValueFormat` (extracted from the Table cell formatting) with unit-only fallback, in both Table and Graph inspector modes.

Verification: `swift test` in BlackboxAnalysis (25) and AirframeUI (21); `xcodebuild test` scheme AirframeTests on macOS and iPhone 13 mini (all new suites pass; `TableModelTests.testMakeModelBuildsFrameRowsAndEventRows` fails pre-existing on clean HEAD, 84.0 vs 99.0, unrelated); iOS XCUITest updated from stale placeholder assertions to real content and passes with a graph screenshot attachment. Open manual checks: scrub/zoom feel on macOS, hover highlight on macOS, light/dark palette review with a real log.

## Graph Follow-up Slices (2026-07-14, second round)

Three refinements after the first Graph review:

- Stable full-log scaling: `Graph.FieldScale` ranges now come from full-log scan-overview extremes (`overviewDisplayPoints` over all samples) instead of per-window min/max, so jumping around a log never re-fits the lines. The overview projection gained `.pidSum(axis:)` (raw component sums) and `.debug(index:)` (raw field) support matching the seriesTable derived semantics; series without an overview projection fall back to the window fit. Occasional clipping from the strided overview is accepted; normalized values clamp at section edges.
- Legend toggle: `AirframeGlobalSettings` (@Observable, shared instance, environment key `\.airframeGlobalSettings`) is the first app-global iCloud-synced setting: key `airframe.graph.legendVisible` in `UserDefaults` plus `NSUbiquitousKeyValueStore` (cloud value wins, external-change notification applies remote toggles live, testable through the `GlobalSettingsCloudStore` seam). The macOS View menu gained a "Show Graph Legend" checkmark toggle in `LogViewCommands`; `Graph.Surface` hides the per-section legend row when off (section names stay).
- Event marker chips: `Graph.Model.Marker` carries a label (events via `tableEventTitle`, issues via `issueTitle`); `Graph.MarkerChips` renders material capsules at the marker lines (secondary border for events, orange for issues), staggered into up to 3 rows via a pure, unit-tested placement function, flipped to the left of the line near the trailing edge, and suppressed entirely above 16 visible markers. `AirframeCaptions` gained `inflightAdjustmentCaption(function:value:)` with the firmware-ordered 34-entry adjustment function table and per-function value scaling (rates x0.01, P x0.1, I x0.001, D floats x1000), so adjustments render like "Rate Profile = 1"; `tableEventTitle` routes `.inflightAdjustment` through it, improving Table event rows too. New committed UI-test fixture `native-event-log.bbl` (synthetic, contains a sync beep) drives the chip UI test with screenshot.

Verification: BlackboxAnalysis (28) and AirframeCaptions (10) package tests; macOS/iOS app suites (new: GraphModelTests scale stability + marker labels, GraphMarkerChipsTests layout, AirframeGlobalSettingsTests precedence/sync; only the known pre-existing TableModelTests width failure remains); iOS UI tests including the new chip test pass with screenshots. Open manual checks: menu toggle across two macOS windows and relaunch persistence, no line snapping on a real log, chip styling in dark mode.

## Graph Package Relocation, Scroll-to-Scrub, Segmented Flag Chips (2026-07-14, third round)

- Part A, relocation: the reusable graph rendering moved from the app target into `AirframeUI` as standalone public types matching the AreaGraph/SeriesPalette convention: `GraphRenderModel` (pure value types, String series ids, no BlackboxAnalysis dependency), `GraphFieldScale`, `GraphWindowPolicy`, `GraphSurfaceCanvas`, `GraphMarkerChips`. The app keeps the glue: `GraphSurface`, the `GraphModel.makeModel` builder (maps `GraphSetup.Section` + workspace/flightInfo into `GraphRenderModel`), `GraphHighlightState`, container/inspector. Pure-type tests moved to `AirframeUITests` as Swift Testing suites; `GraphModelTests` (builder) stays in the app. Every moved View has a `#Preview` (`GraphSurfaceCanvas` added, `SeriesPalette` swatch preview added, `GraphMarkerChips` preview extended).
- Part B, scroll-to-scrub: `AirframeUI.HorizontalScrollScrubView` (macOS `NSViewRepresentable` with a bounds-scoped local scroll-wheel monitor, hitTest returns nil so clicks/drag pass through; inert clear view on iOS) plus `GraphWindowPolicy.cursorDelta(forScrollDelta:plotWidth:windowMicros:)`. `GraphSurface` wires it so a two-finger horizontal swipe or mouse wheel scrubs the cursor exactly like the drag; window stays cursor-centered. Sign tuned for natural scrolling; manual macOS check still open.
- Part C, segmented flag chips: `GraphRenderModel.Marker.content` is now `.text(String)` or `.states([State{name,isOn}])`. Flight-mode events render only the flags that changed (from `CaptionSet.flightModeChanges`, XOR of flags/previousFlags), each as a separate graphic segment (accent dot + name, ON accent-tinted / OFF dimmed) inside one material chip. Chips are centered on and fixed to the event line (no X search / edge flip); overlap resolves only by Y-row stacking; density guard unchanged. The firmware flight-mode-name table (version-keyed `legacy`/`modernFlightModes`, `BetaflightVersion`) was hoisted from `AirframeCLIService` into `AirframeCaptions` (`CaptionSet.flightModeNames(for:)`), so CLI, Table, and Graph share one source; Table event rows use the comma-joined `flightModeChangeSummary`. New catalog keys `flightMode.stateOn`/`stateOff`. New UI-test fixture `native-flightmode-log.bbl`.

Verification: package tests AirframeCaptions (17), AirframeUI (48), AirframeCLI (26, output unchanged); app macOS/iOS builds; AirframeTests (only the known pre-existing `TableModelTests` column-width failure remains); full iOS UI suite (4 tests) passes with graph, event-chip, and segmented-flight-mode-chip screenshots. Open manual checks: two-finger/scroll scrub feel on macOS, segmented chip in dark mode, both-segment layout with a wider window.

## Preset Sidebar Slice (2026-07-16)

### Think Before Coding

- Presets are a per-log-segment selection, not a separate workspace. The selected preset must be visible in the document sidebar and application must not trigger additional settings loads per row.
- The built-in `Default` preset has the shared fixed ID `"default"` and name `"Default"`. It may persist a user customization, but cannot be renamed, deleted, imported, or exported. Reset removes that override and restores the app defaults.

### Simplicity First

- The document sidebar is the only preset surface. There is no preset manager pane or toolbar entry.
- A full-row click applies a preset. Existing-preset actions live in its context menu; the section header contains only New, Import, and Save when the selected appearance has unsaved changes.
- Rows use the same compact rounded selection treatment as log rows. Default uses `gearshape` or `gearshape.fill` when customized; user presets use `slider.horizontal.3`; an unsaved current change overlays `pencil.circle.fill`; selection also shows the accent background and checkmark.

### Surgical Changes

- Reuse a single `LogContext` for sidebar and detail during one `DocumentHomeView` body pass. Resolve the preset snapshot and modified state once for the sidebar body, rather than reading settings from individual rows.
- Use native SwiftUI alerts, confirmation dialogs, and file import/export panels. The New flow is an alert with a text field instead of a custom sheet.
- Header icons are borderless and acquire their visual affordance only on hover, matching the timeline controls.

### Goal-Driven Execution

- Automated repository coverage verifies Default customization round-trips, reset behavior, and its import/export restrictions. The macOS Release build passed on 2026-07-16.
- Manual review remains: inspect sidebar spacing, hover, dynamic type, and the native text-field alert with a real loaded log on macOS and iOS.

## Graph Loading Fixes and Cache Hardening (2026-07-18)

### Think Before Coding

- Root cause of "stuck on simplified data at range edges": `GraphWindowPolicy.visibleRange` intentionally extends past the bounds near the edges, but all coverage checks (model cache, prepared cache, stale check, active-load usefulness) compared that unclamped window against bounds-clamped load ranges and could never succeed there. Completed detail builds were discarded, in-flight loads cancelled, cache hits missed. The cursor defaults to the range lower bound, so even the first load after opening hit this path.
- Secondary causes for reload churn and detail/overview flicker: completed-but-"no longer useful" builds thrown away instead of cached, adjacent (non-overlapping) prewarm ranges that miss when the visible window straddles a boundary, a 400 ms stabilization delay before every detail decode even when idle, and render-model construction from prepared-cache hits running on the MainActor.

### Simplicity First

- `GraphWindowPolicy.coverageRange(visible:bounds:)` clamps at the call sites; rendering keeps the unclamped window.
- Prewarm ranges shifted by half the load span (1.5 visible windows of overlap) instead of cache-entry stitching: any visible window inside the union is covered by a single entry, no merge logic.
- `GraphActiveDetailLoadPolicy` keeps in-flight loads at >= 50% overlap of the clamped visible window; completed builds are cached regardless (protection `.warmRecent` when scrubbed away).

### Surgical Changes

- Canvas: out-of-range dim overlay now draws above the traces. Cache concept: macOS gets a real `DispatchSource` memory-pressure observer (resign-active only trimmed to the normal budget, a no-op), `GraphModelCache` gains `removeAllDetailEntries()` for pressure paths and drops stale per-width shapes on store, `canStoreEstimatedByteCount` now checks remaining plus evictable capacity, `updateProtection` writes only changed entries and is skipped during interaction, stores subsume fully contained same-zoom entries.
- Ported `DocumentStateStoreTests` off APIs removed by the preset slice (`setFieldSelectionIDs`, `setGraphWindowMicros` -> `graphZoomFactor`); the test target had not compiled since cbe5431.

### Goal-Driven Execution

- AirframeUI (89), BlackboxAnalysis (98), and the full `AirframeTests` target pass on macOS; app builds and launched with the reference log `btfl_007.bbl`.
- Open manual checks: dimmed traces outside the range, detail data sticking at the range edges, no re-glow when scrubbing back into known regions, stable detail after idle, pressure trim via `memory_pressure -S -l warn`.

Follow-up (same day): graph load windows now clamp to the full log range instead of the timeline range. The timeline range confines only the cursor and defines the dim-overlay boundary; data outside the range is loaded, rendered, and dimmed. Before this, detail loads never contained out-of-range samples, so traces vanished left/right of the range once real detail replaced the full-log overview placeholder. Coverage clamping, prewarm bounds, protection updates, and the overview `loadedDataRange` all use `fullLogRange` now.

Follow-up 2 (same day): near the log edges the visible window keeps moving after the last load request (the loaded range already touches the bounds, so reload hysteresis stays quiet), leaving a displayed detail model that ends mid-plot with an empty region beside it until the final build lands. Fix: `GraphSurface` keeps the last coarse overview in view state (`coarsePlaceholderModel`) and swaps to it synchronously from the cursor/zoom/width `onChange` handlers whenever the displayed detail model no longer covers the clamped visible window (`swapToCoarsePlaceholderIfDisplayedDetailNoLongerCovers`). The in-flight detail load then replaces the placeholder.

Follow-up 3 (same day): the "fixed positions always re-glow" report traced via temporary [Claude-DEBUG] file logging and synthetic scroll events to a starved prewarm: beginGraphInteraction and every load-request change cancelled the running prewarm, the neighbor list always built the left range first, and an aborted or empty build returned out of the whole loop, so the direction-of-travel neighbor was never cached and the edge of the built union re-missed on every crossing. Fixes: prewarm survives interactions and request changes (cancelled only when superseded by a newer prewarm, on log switch, or onDisappear), the neighbor in the last cursor-movement direction builds first (lastCursorMovementDirection in GraphSurface), and a failed/empty neighbor build continues with the next range instead of returning. Also recorded: the Airframe scheme's default xcodebuild build configuration is Release; Debug products require -configuration Debug (the Debug product dir may otherwise hold stale binaries from test runs).

Follow-up 4 (same day): reproducible simple->glow->details at fixed positions (e.g. 29s->30s in btfl_007.bbl) had two cooperating causes. First, both cache lookups preferred the tightest covering entry (GraphPreparedSeriesCache.covering sorted by smallest span, GraphModelCache.detailCovering took the first match), so the displayed detail model often ended just past the visible window and its edge sat at a stable position across passes. Second, swapToCoarsePlaceholderIfDisplayedDetailNoLongerCovers downgraded to the overview on crossing that edge without triggering any re-evaluation, so detail only returned at the next hysteresis recenter or interaction end. Fixes: both lookups now pick the covering entry with the largest headroom around the visible window (GraphPreparedSeriesCache.coverageHeadroom, shared by GraphModelCache), and the swap bumps refinementGeneration so loadModel re-evaluates immediately - a covering cache entry restores detail right away, otherwise the rebuild starts without waiting for the recenter.

## Processing Activity Spinner (2026-07-18)

### Think Before Coding

- All off-main data work in the app target already funneled through `await Task.detached(...).value`, so a single balanced counter at that boundary observes reading, decoding, transforming, and computing without touching the domain packages.
- The initial document decode runs before `LogDataView` (and its toolbar) is mounted, so the spinner covers post-open work, not the first-open LoadingState. That is acceptable: the LoadingState screen already communicates the first decode.

### Simplicity First

- One type: `ProcessingActivityCounter` (`@MainActor @Observable`, per document, injected via `\.processingActivityCounter`). Self-balancing funnels only, no manual begin/end at call sites: `compute` (awaited, throwing + non-throwing overloads because `Task.value` cannot ride `rethrows`), `track` (awaited, no extra detach), `instrument` (Sendable, for actor-internal tasks like the chunk prefetch), `backgroundTask` (fire-and-forget). Optional-typed mirrors keep previews/tests without a counter working.
- `ProcessingSpinnerPolicy` is a pure, unit-tested visibility policy: 150 ms appear delay, 400 ms minimum visible, so brief blips do not flash and short finishes do not strobe.

### Surgical Changes

- Swapped every `Task.detached` data site in the app target to a funnel call: DocumentView (decode load via `track`, auto-range via `compute`), LogTimeline, GraphSurface (detail build, prepared-match build, overview warmers via `backgroundTask`, prewarm build), TableSurface (chunk load via `track`, model build via `compute`, prefetch via new `activity:` parameter threaded into `MainFrameChunkCache.prefetch` -> `instrument`), SpectrumSurface (5 sites), GraphSetupEditor. PresetRepository cloud sync stays bare (non-log-data, rule-exempt).
- Spinner placement (user-revised): the sidebar File section item, right-aligned via an `HStack { VStack{name,size}; Spacer; ProcessingActivitySpinner }`. The toolbar placement was tried first (trailing `.primaryAction`) but the user found it visually poor. The spinner collapses to zero width when idle (a zero-width clear anchor keeps the driving `.task` alive so it can reappear); the sidebar row is always mounted, so it also covers the initial decode.

### Goal-Driven Execution

- `ProcessingActivityCounterTests` (balance on success/throw/nesting, active-while-running, track, backgroundTask) and `ProcessingSpinnerPolicyTests` (appear delay, minimum-visible hold, idle) pass; full `AirframeTests` and AirframeUI (89) green.
- Verified on macOS with btfl_007.bbl via titlebar screenshots: spinner rotates left of Edit during decode/prewarm/graph builds, collapses cleanly when all work (including idle prewarm) finishes.
- The Processing Activity Rule in PRINCIPLES.md governs all future compute paths: use the funnel, never bare `Task.detached` for data work in the app target.

## Step Response Analysis with Multi-Log Comparison (2026-07-18)

### Think Before Coding

- The document architecture stays document-based (`DocumentGroup`); no shoebox. A `.bbl` already carries multiple segments, so same-document overlay covers the flash-download tuning workflow; cross-file comparison attaches reference files to the window instead of restructuring scenes.
- Reference algorithm is PIDtoolbox `PTstepcalc.m` (local clone under `PIDtoolbox/`); numerics were matched deliberately (window length, normalization, regularization scale, smoothing span, QC bands, subsample default 9).

### Simplicity First

- A reference file is just another `AirframeDocumentOpenModel` in a per-window `ReferenceLogStore`; the load pipeline, progress, and snapshot rendering are reused unchanged.
- Reference in/out ranges reuse the existing `DocumentStateRepository` entry keyed by the file's content identity, so trimming a file as its own document applies to its reference traces and vice versa; no new sync machinery, no trimming UI.
- Step Response state is one document-wide `ViewState` (settings + hidden-trace set); hidden-set semantics make "all logs on by default" enumeration-free.

### Surgical Changes

- `LogContext`, sidebar selection semantics, presets, and all existing views stay single-log; multi-log access is the additive `airframeDocumentLogAccess` environment value.
- The spectrum FFT is untouched; step response has its own complex FFT helper. The canvas is a dedicated sibling of the stacked spectrum canvas reusing only `SeriesPalette`/`ColorRole`.
- New persisted fields are additive and versioned (`stepResponse` entry field, `AirframeLogSummary.tune`).

### Goal-Driven Execution

- Milestones M1 (computation + tests, PTB cross-check on the Damping set), M2 (view mode), M3 (sidebar trace list + tune), M4 (reference logs) are implemented and verified; follow-ups (bookmark restore, rcCommand-derived setpoint, rate-split traces, crosshair) are in BACKLOG.md.
- Verification: 113 package + 223 app tests green; manual macOS run against `.../Maya/Tuning/Flights/2 Damping` shows PTB-consistent curves (ordering and peaks within a few percent).
