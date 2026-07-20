# Planning Tasks

## Series Presentation Follow-up

- Keep the Reader series presentation resolver and AirframeCaptions lookup in sync whenever a new selectable field family or debug-mode meaning is introduced. Add conversion and caption coverage in the same change.

## Near Term

- Graph playback is implemented (2026-07-20): Graph-only Play/Pause toolbar controls drive the shared current position to the active Out point, restart from In when already at Out, pause on view/log changes, and use a monotonic anchor. Playback speed is globally persisted from 0.3x through 3.0x in 0.1x steps, default 1.0x. Future video synchronization should use this same master position/rate rather than adding an independent timer.

- Current automatic timeline range/settings slice is implemented (2026-07-15):
  - `AirframeGlobalSettings` has iCloud-synced `isAutomaticTimelineRangeEnabled`, key `airframe.timeline.automaticRangeEnabled`, default true.
  - macOS exposes `SettingsView` through the native Settings scene with a `General` tab.
  - iOS/iPadOS expose `SettingsView` from the Home toolbar gear as a sheet with a `General` form section.
  - `AirframeCaptions` owns the new settings title, General label, toggle label, and explanation strings.
  - `ReaderScanOverview` retains `lastTerminationEventContextMainFrameTime` for final disarm/log-end context even when the bounded event-record list truncates.
  - `BlackboxAnalysisWorkspace.automaticTimelineRange(using:)` detects exact conservative ranges: full log >= 20 s, In at the first exact motor average at least 8 percentage points above the observed idle floor and sustained for 500 ms / 80% of samples, Out at final termination context minus 2 s, otherwise final exact 0 % fallback, otherwise final main-frame time minus 2 s, range duration >= 10 s.
  - `DocumentStateStore` distinguishes stored ranges from the full-log fallback and atomically applies automatic ranges without overwriting existing stored ranges.
  - `DocumentView` runs detection after document opening, off the main actor, persists only when a range is actually written, logs detector errors, and respects cancellation/state rechecks.
  - Follow-up implemented: `Reset File Settings` now triggers the same missing-range automatic application after clearing document state, and the Timeline toolbar has a small `Auto` button directly left of In. The button manually recalculates and replaces the active segment's stored range; automatic open/reset application remains no-overwrite.
  - Diagnostic logging is enabled for the Auto path: app application logs use `airframe.documents`, and detector calculation logs use `airframe.analysis.automaticRange`.
  - Spectrum production range behavior is unchanged; regression coverage verifies compute-key range bounds and `spectrumSamples` requested bounds.
  - Verification passed: Reader, Analysis, Captions, and UI package tests; macOS and iOS focused app tests; macOS and iOS Debug app builds. The unavailable local `iPhone 13 mini` simulator was replaced with the available `iPhone 17` / iOS 26.5 destination.
- Document-wide Table/Graph field picker implemented (2026-07-13): one shared persisted selection, tri-state group bulk controls, unavailable-ID retention across schemas, and legacy per-log state ignored.
- Current Table alignment and macOS inspector layout fix is implemented: Table cell widths include padding and rows share the header's leading content width; macOS uses SwiftUI's native inspector, and Table retains local geometry when the system overlays the inspector at narrow widths.

- Current AirframeCaptions localization-rule slice is implemented:
  - `Airframe/Packages/AirframeCaptions` exists as the shared user-facing caption package.
  - It uses SwiftPM-processed Xcode `.xcstrings` resources at `Sources/AirframeCaptions/Resources/Localizable.xcstrings`, with explicit English source entries rather than relying on runtime `defaultValue` fallbacks.
  - It exposes typed caption APIs through `CaptionSet`, `Caption`, `AppCaptionID`, and convenience extensions for domain semantic keys.
  - It owns centralized captions for Reader series, derived Analysis series, info section/row keys, events, issues, selected app placeholders/control labels, unit symbols, and flight-mode display names.
  - Architecture correction: `BlackboxAnalysis` does not depend on `AirframeCaptions`; it owns derived semantics through `AnalysisDerivedSeriesKind`, and `AirframeCaptions` maps that domain key to localized captions for App/CLI.
  - `AirframeCLI` now derives human event summaries and issue messages from `AirframeCaptions` while keeping machine-readable JSON keys local.
  - App Table, Timeline, and debug preview marker labels now use `CaptionSet`; `AirframeUI` re-exports `AirframeCaptions` for app consumers.
  - A focused guardrail test in `AirframeCaptionsTests` fails if migrated event/issue/series caption literals reappear in App, CLI, or Analysis source.
  - `HANDOFF.md` was removed after the correction was implemented.
  - Verification passed after the architecture correction and explicit catalog population: `swift test` in `AirframeCaptions`, `BlackboxAnalysis`, `AirframeCLI`, and `AirframeUI`; `xcodebuild test -project Airframe/App/Airframe.xcodeproj -scheme AirframeTests -destination 'platform=macOS' -derivedDataPath /tmp/airframe-captions-correction-macos-dd`; `xcodebuild test -project Airframe/App/Airframe.xcodeproj -scheme AirframeTests -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 13 mini' -derivedDataPath /tmp/airframe-captions-correction-ios-dd`; `xcstringstool compile --dry-run` for the AirframeCaptions catalog; `git -C Airframe diff --check`.
  - Follow-up: migrate `ReaderInfoReportBuilder` out of Reader-owned hardcoded labels into a Caption-backed report builder without creating a Reader -> Captions dependency cycle.
- Current center-locked Table slice is implemented: Main-frame rows snap one at a time at the fixed viewport-center cursor; endpoint overscroll is intentional; Timeline range filters all visible Table frames/events; table-local cursor clamping does not modify global Timeline position; cached Timeline scrubbing re-centers without rebuilding the Table model.
- Current app shell slice is implemented:
  - `Airframe/App/Airframe.xcodeproj` exists.
  - App target/product/display name is `Airframe`.
  - Bundle ID is `com.kumkju.airframe`.
  - Local package products from `Airframe/Packages` are linked through the Xcode project.
  - `AirframeUI` package exists for shared SwiftUI metadata UI.
  - The app uses `DocumentGroup` and a read-only `LogDocument`.
  - `.bbl` and `.bfl` are registered as viewer document types.
  - `.txt` and `.log` are intentionally not registered.
  - English string catalog and placeholder asset catalog are present.
  - Team ID is configured through `Base.xcconfig`; final icon is deferred.
- Current unit-formatting slice is implemented:
  - `AirframeUnits` is a dependency-free Swift package for duration, frequency, integer, and percent formatting.
  - `AirframeUI` provides `DurationText`, `FrequencyText`, `IntegerText`, and `PercentText` value views.
  - Document timing/sidebar/count values use these views; progress and issue strings use focused formatters.
- `Airframe/Packages/Logging` is implemented as a copied local infrastructure package:
  - `Logging` target writes to `os.Logger` and keeps an in-memory session buffer.
  - `ErrorReporting` and Sentry were removed; the package has no external dependencies.
  - The `Logging` package product is linked into the `Airframe` app target.
  - `BlackboxReader`, `BlackboxAnalysis`, `AirframeUI`, and `AirframeCLI` consume it through package-local `PackageLog` categories. `BlackboxCore` intentionally remains logging-free.
  - Current categories: `blackbox.reader`, `blackbox.stream`, `blackbox.analysis`, `airframe.documents`, and `airframe.cli`.
  - `swift test` passed in the Airframe copy with 14 Swift Testing tests in 1 suite.
- Completed product slice: `AirframeCLI` executable package with command `airframe`.
- `AirframeCLI` uses the approved `apple/swift-argument-parser` dependency.
- `AirframeCLI` is split into testable `AirframeCLIKit` library target and a thin executable target.
- CLI includes `--help`, `--version`, `--completion bash|zsh|fish`, `logs`, `header`, `info`, `schema`, `validate`, `fields`, `issues`, `events`, `data`, and `csv`.
- CLI `info` output renders a Reader-owned semantic setup report for quad/setup metadata. `BlackboxReader` owns header-name recognition, canonical keys, derived values, and section semantics; `AirframeCLI` only formats sections and rows. Modern sections include D-Term / PID, Feedforward, RPM Filter, GPS / Rescue, Altitude / Autopilot, and Flight Modes when values exist. Default output hides empty rows/sections; `--show-empty` restores them.
- CLI data extraction treats `I`, `P`, `S`, `G`, and `H` as first-class frames for schema, validation, data extraction, and CSV. `E` is event output, not numeric series.
- CLI `schema` keeps JSON structured while text output labels each frame marker with a colon, e.g. `I: ...`, `G: ...`, `H: ...`.
- CLI filtering starts with simple flags and presets, not a full query language. It includes exact fields, globs, marker filters, presentation groups, case-insensitive name contains, known/unknown filters, queryable-only, and presets for current, motor, rpm, gps, and power.
- CLI `issues` exposes import, header, compatibility, stream, range, selector, and optional CSV issues as text/JSON so tools do not need to parse unrelated command output.
- CLI `events` exposes decoded event frames as human-readable timeline text by default and JSON/NDJSON for tool consumers, with event type, payload, byte range, ordinal, and time/context fields for later timeline/UI and script consumers. Text output uses relative seconds from the first valid main frame, readable event labels such as `Disarm` and `End of log`, robust firmware-version parsing for full Betaflight revision strings, and the currently active primary flight mode such as `Flight mode Angle` or `Flight mode Acro` instead of changed-flag `on`/`off` lists.
- CLI JSON contract decision: omit source file names from machine JSON; use `source`, `log`, and offsets as stable identity.
- CLI snapshot/output tests now cover `info`, `schema`, `fields`, `validate`, `issues`, and `events`; events also has default text-output and CSV-rejection coverage.
- Local CLI smoke script passed against `Flightlogs/small/`: `logs`, `header`, `info`, `schema`, `fields`, `csv`, `validate`, `issues`, and `events` completed for all 3 staged logs. The script intentionally ignores `validate`'s exit code for real local logs because its purpose is command-completion smoke coverage, not asserting every staged private log is issue-free.
- Reader all-frame field table and CSV layer exists for `I`, `P`, `S`, `G`, and `H`.
- Reader golden frame-stream snapshot validation exists for `single-log-basic`, `gps-home-flow`, and `event-flow`.
- External validation with `blackbox-tools` / `blackbox_decode` is intentionally deferred. Use as little upstream behavior as possible for the next slices.
- Reader lazy decoded-log API exists: `DecodedLog`, `ReaderLogSchema`, `ReaderFrameSchema`, `ReaderField`, `NamedReaderFrame`, `decodedLogs(in:)`, `decodedLog(for:in:)`, and `namedFrame(_:using:)`.
- Reader memory-light summary API exists: `DecodedLogSummary`, `ReaderEventSummary`, `DecodedLogSummaryResult`, `DecodedLog.summarize()`, and `BlackboxReader.summaries(in:)`.
- Reader fast header-preview API exists: `ReaderHeaderPreviewOptions`, `ReaderHeaderPreview`, `DecodedLogHeaderInfo`, `DecodedLog.headerInfo`, `BlackboxReader.headerInfos(in:)`, and `BlackboxReader.previewHeaders(fileAt:options:)`.
- Reader header catalog and semantic report API exists: `ReaderHeaderKey`, `ReaderHeaderDefinition`, `ReaderHeaderValueKind`, `ReaderHeaderSemanticKey`, `ReaderHeaderSemanticValue`, header lookup helpers on `DecodedLogHeaderInfo`, and `DecodedLogFlightInfo.infoReport(showEmpty:)`. `ReaderInfoRow` exposes `displayValue`, `rawValue`, and `typedValue`; legacy `value` remains a display alias.
- Reader scan-backed flight-info API exists: `DecodedLogFlightInfo`, `DecodedLogFlightInfoResult`, `DecodedLog.flightInfo(using:)`, and `BlackboxReader.flightInfos(in:)`.
- Reader syncpoint index API exists: `ReaderLogIndex`, `ReaderSyncPoint`, `ReaderLogIndex.Error`, and `DecodedLog.makeIndex()`.
- Reader single-pass metadata/index scan API exists: `DecodedLogScan`, `DecodedLogScanProgress`, and `DecodedLog.scan(progressHandler:)`.
- Reader partial main-frame range API exists: `ReaderMainFrameRange`, `ReaderMainFrameRange.Error`, extended `ReaderSyncPoint` state, and `DecodedLog.mainFrames(fromMainFrameTime:throughMainFrameTime:using:)`.
- Reader all-frame range API exists: `ReaderFrameRange`, `ReaderFrameRange.Error`, and `DecodedLog.allFrames(fromMainFrameTime:throughMainFrameTime:using:)`.
- Reader selected main-frame field-range API exists: `ReaderFieldSelector`, `ReaderFieldSample`, `ReaderFieldRange`, and `DecodedLog.mainFrameFields(...)`.
- Reader consumer series API exists: `ReaderSeriesID`, `ReaderSeriesDescriptor`, `ReaderSeriesFrameGroup`, `ReaderSeriesCatalog`, `ReaderSeriesSelector`, `ReaderSeriesTable`, `ReaderViewportResult`, `ReaderSeriesCSV`, `ReaderSeriesRequest`, and `DecodedLog` helpers for catalog, table, viewport, and CSV generation.
- Reader series presentation API exists: `ReaderSeriesPresentation`, `ReaderSeriesUnit`, `ReaderSeriesPresentationGroup`, `ReaderSeriesAxisHint`, `ReaderSeriesValueScale`, `ReaderSeriesDescriptor.presentation`, `ReaderSeriesCatalog.presentation(for:)`, and `ReaderSeriesCatalog.presentedDescriptors(for:)`.
- Series presentation is project-owned metadata for raw Reader series. It provides labels, short labels, groups, conservative units, precision, axis hints, raw scale metadata, and known/unknown status without adding upstream graph/config concepts, decoded-value scaling, derived fields, or UI.
- Reader display-value API exists: `ReaderSeriesDisplayValue`, `ReaderSeriesDisplayContext`, and `ReaderSeriesPresentation.displayValue(for:context:)`. It currently scales `time` to seconds and GPS coordinate integers to coordinate degrees; all uncertain fields remain raw.
- `BlackboxAnalysis` package exists and depends on `BlackboxReader`.
- Analysis app-facing facade exists through `BlackboxAnalysisWorkspace`, `AnalysisSeriesCatalog`, `AnalysisSeriesTable`, and `AnalysisViewportResult`.
- Analysis catalog unifies raw Reader passthrough, display-scaled raw values, and first derived series so app consumers do not need to know which package owns each value.
- First Analysis derived series implemented: motor minimum, motor maximum, motor average, PID sum per qualifying axis, and debug raw descriptors with debug-mode label context.
- GPS distance/azimuth/local coordinates and attitude series are represented in `AnalysisDerivedSeriesKind` but are prerequisite-gated and currently omitted from the catalog when alignment/scaling is not proven.
- Keep `BlackboxCore` limited to parser primitives. `BlackboxReader` is now the separate package for file loading, lazy decoded-log access, full frame-stream iteration, recovery/resync, import assembly, multi-file import behavior, and compatibility status handling.
- Local-only summary smoke/performance checks on `Flightlogs/small/` passed: 3 files, 3 decoded logs, 0 import issues, 0 stream issues, 0 corrupt frames, baseline open `0.0101s`, batch summaries `0.3362s`, max RSS `10.9MB`.
- Local-only index smoke checks on `Flightlogs/small/` passed: 3 files, 3 decoded logs, 0 import issues, syncpoints `29`, `28`, and `117`, 0 index issues.
- Local-only range smoke checks on `Flightlogs/small/` passed: bounded main-frame output matched full-stream filtered output exactly for all 3 logs, with 0 range issues.
- Local-only scan smoke checks on `Flightlogs/small/` passed: `DecodedLog.scan()` matched separate `summarize()` plus `makeIndex()` for all 3 logs, with 0 import issues, 0 total issues, and 174 total syncpoints.
- Local-only header-preview smoke checks on `Flightlogs/small/` passed using only `BlackboxReader().previewHeaders(fileAt:)`: Barney read `33,554/33,554` bytes, Flip read `49,152/49,152` bytes, and Puck read `65,536/174,080` bytes while returning complete headers.
- Local-only flight-info/field-range smoke checks on `Flightlogs/small/` passed using `scan()`, `flightInfo(using:)`, and `mainFrameFields(... using: scan.index)`: selected samples were Barney `204`, Flip `507`, and Puck `249`, all with 0 issues.
- Local-only series smoke checks on `Flightlogs/small/` passed using `scan()`, `seriesCatalog`, `seriesTable(for:using:)`, `viewportSeries(for:using:)`, and `seriesCSV(for:using:)`: Barney `groups=5`, `mainSeries=96`, `rows=731`, `viewportPoints=458`, `csvRows=731`, `issues=0`; Flip `groups=3`, `mainSeries=68`, `rows=1770`, `viewportPoints=456`, `csvRows=1770`, `issues=0`; Puck `groups=5`, `mainSeries=106`, `rows=3723`, `viewportPoints=634`, `csvRows=3723`, `issues=0`.
- Local range performance benchmark on 8MB to 30MB private logs showed 1% all-frame ranges around `12ms...48ms`, 5% all-frame ranges around `61ms...236ms`, and near-identical `mainFrames(...)` / `allFrames(...)` timings.
- Local scan performance benchmark showed `DecodedLog.scan()` is about `2x` faster than current separate `summarize()` plus `makeIndex()` calls, and about `1.6x` faster than the earlier pre-scan Summary+Index baseline on larger private logs.
- Cache decision: defer chunk cache. `DecodedLog.scan()` now handles the measured duplicate full-log decoding case when callers need both summary and index.
- First security-hardening slice completed before UI/chart work:
  - Core checked arithmetic and bounded scanner/interpreter limits are implemented.
  - Reader configuration budgets are implemented for import/source/header/event/issue/index/range/sample/selector/CSV/preview/concurrency surfaces.
  - Event log-end messages are bounded.
  - Issue floods are capped while preserving total issue counts.
  - Range, field, selector, syncpoint, viewport, and CSV output limits are enforced.
  - Analysis aggregate sums avoid `Int` overflow traps.
  - Hostile-input/limit tests cover oversized in-memory sources, header limits, event string caps, retained issue caps, range and selector limits, CSV row/byte limits, scanner limits, field-count limits, and predictor overflow.
- Aggressive permanent hostile-input smoke coverage completed:
  - Core covers deterministic random bytes, marker spam, hostile scanner headers, and hostile interpreter definitions.
  - Reader covers deterministic random imports, oversized input rejection, mutated valid fixtures through stream and scan paths, hostile header preview files, and range/series output pressure.
  - External coverage-guided fuzzing is deferred and parked in `.agents/BACKLOG.md`.
- First pre-commit audit fixes are implemented and covered:
  - Reader log-end event string byte-limit edges.
  - Reader suspicious logging-resume issue before any main-frame baseline.
  - Header-preview truncated-tail tolerance.
  - CLI absolute-path sanitization in error messages.
- Current automated coverage after frame-level progress:
  - `BlackboxCore`: 94 Swift Testing tests in 12 suites.
  - `Logging`: 14 Swift Testing tests in 1 suite.
  - `BlackboxReader`: 164 Swift Testing tests in 24 suites.
  - `BlackboxAnalysis`: 8 Swift Testing tests in 3 suites.
  - `AirframeUI`: 5 Swift Testing tests in 1 suite.
  - `AirframeCLI`: 26 Swift Testing tests in 2 suites.
  - `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/airframe-frame-progress-test-dd` passed after frame-level progress.
- Current progressive document-opening slice is implemented:
  - `LogDocument` now stores source name, bytes, byte count, and identity only.
  - `DocumentView` owns `AirframeDocumentOpenModel` and starts async loading from `.task(id:)`.
  - `AirframeUI` exposes `AirframeDocumentOpenState`, `AirframeDocumentSnapshot`, and per-log `AirframeLogDetailState`.
  - Header/log metadata appears from the fast Reader open/header path before scan-backed `flightInfo()` details finish.
  - The left list stays focused on file/log identity without scan status.
  - While a log is scanning, the right detail view shows Summary plus one determinate progress row; timing/frame-count sections appear after the scan finishes.
  - The progress bar now advances during each log scan from `DecodedLogScanProgress` emitted after every decoded frame. Percent is byte-range based; text includes decoded frame count. UI progress is clamped and monotonically applied to avoid transient values above 100%.
  - Progress, timing metadata, main-frame counts, and issue numbers use locale-aware number formatting instead of direct numeric string interpolation.
  - Empty/non-Blackbox documents still surface import issues in the document window.
  - Verification passed: `swift test` in `Airframe/Packages/BlackboxReader`; `swift test` in `Airframe/Packages/AirframeUI`; `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/airframe-frame-progress-test-dd`.
- Current state-restoration slice is implemented:
  - `DocumentGroup` has macOS minimum/default document sizing. System state restoration should restore the most recent window size after that initial default.
  - `DocumentHomeView` persists `NavigationSplitView` column visibility with `@SceneStorage`.
  - The selected log row is restored per scene with `@SceneStorage`.
  - The sidebar has stable `navigationSplitViewColumnWidth(min:ideal:max:)` values.
  - Exact persistence of manually dragged sidebar widths is not custom-implemented; keep using SwiftUI restoration unless real macOS testing shows it is insufficient.
  - Verification passed: `swift test` in `Airframe/Packages/AirframeUI`; `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/airframe-state-restoration-test-dd`; `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=macOS' -derivedDataPath /tmp/airframe-state-restoration-macos-test-dd`.
- Current iPhone full-screen fix is implemented:
  - Added the minimal `UILaunchScreen` dictionary to the manual app `Info.plist`.
  - Before the fix, the iPhone 17 simulator showed Airframe letterboxed inside the screen.
  - After reinstalling the rebuilt app, the screenshot used the full screen; the remaining large rounded card is the system `DocumentGroup` document browser design.
  - Verification passed: `xcodebuild build -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/airframe-fullscreen-fix-dd`; `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/airframe-fullscreen-fix-test-dd`; simulator launch screenshot `/tmp/airframe-iphone-fullscreen-fix.png`.
- Current iOS no-document-browser slice is implemented:
  - iOS now uses `WindowGroup { HomeView() }` instead of `DocumentGroup` as the root scene.
  - `HomeView` provides a direct empty state, toolbar open button, `fileImporter`, and `onOpenURL` handling.
  - `LogDocument(fileAt:)` reads security-scoped file URLs for importer/external-open flows.
  - macOS still uses `DocumentGroup` and document-window sizing from `AirframeApp`.
  - Verification passed: `xcodebuild build -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/airframe-no-document-browser-dd`; iPhone simulator screenshot `/tmp/airframe-no-document-browser.png`; `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/airframe-no-document-browser-test-dd`; `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=macOS' -derivedDataPath /tmp/airframe-no-document-browser-macos-test-dd`.
- Current UI-test infrastructure slice is implemented:
  - `AirframeLaunchContext` detects UI-test runs through `--airframe-ui-testing` or `AIRFRAME_UI_TESTING=1`.
  - UI-test fixture injection supports launch arguments `--airframe-ui-test-fixture-name` and `--airframe-ui-test-fixture-base64`, plus equivalent environment keys.
  - `AirframeUITests` exists as an XCUITest target with bundled compact fixtures `native-single-log.bbl` and `native-gps-flow.bfl`.
  - The iOS/iPadOS UI test opens a bundled fixture without using the system file picker and verifies visible firmware, compatibility, and main-frame metadata.
  - The macOS UI test source uses bundled fixture bytes, staged inside the app sandbox before native document opening. It is opt-in with `AIRFRAME_ENABLE_MACOS_UI_TESTS=1` because the current local host starts the app as `Running Background` under macOS XCUITest.
  - Normal macOS Debug and Release launches use `DocumentGroup`.
  - Explicit macOS UI-test fixture injection is Debug-only, requires UI-test mode, and opens the staged fixture through native document infrastructure after launch.
  - Verification passed: `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/airframe-uitests-ios-dd`; `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=macOS' -derivedDataPath /tmp/airframe-uitests-macos-dd` with the macOS direct-file UI test skipped by default; `xcodebuild build-for-testing -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=macOS' -derivedDataPath /tmp/airframe-uitests-macos-build-dd`; `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=macOS' -skip-testing:AirframeUITests -derivedDataPath /tmp/airframe-uitests-macos-unit-dd`; `swift test` in `Airframe/Packages/AirframeUI`; `swift test` in `Airframe/Packages/BlackboxReader`.
  - macOS UI-test execution got past the initial Automation permission issue after the user accepted the dialog, but still times out at app activation with `Failed to activate application ... (current state: Running Background)`. Keep the test opt-in until the host/Xcode runner issue is resolved.
- Current App Store sandbox/iCloud document-state slice is implemented:
  - macOS app signing enables App Sandbox and read-only user-selected-file access; iOS/macOS signing enables iCloud Key-Value Storage.
  - `DocumentStateRepository` mirrors only the per-document LRU buffer to iCloud, merges updates by timestamp, and remains local-only when iCloud is unavailable.
  - Open windows intentionally ignore remote state updates; only later windows consume merged state.
  - No security-scoped bookmarks or document URLs are stored.
  - macOS UI-test fixture injection uses in-memory data staged in the app sandbox's temporary directory before native document opening; it does not rely on arbitrary external file paths.
- Current macOS launch behavior slice is implemented:
  - Quit/login never restore prior document windows.
  - Reopening a window-free running app presents the native Open dialog.
  - Closing the final document leaves no window open.
- Current document diagnostics slice is implemented:
  - `airframe.documents` logs identity calculation, local state hits/misses, unchanged state skips, local saves, iCloud synchronization, merges, and saves.
  - Diagnostics use only source names, byte/state counts, and shortened identity prefixes.
- Current iPhone document navigation fix is implemented:
  - `HomeView` shows the opened `DocumentView` directly instead of embedding it inside the home `NavigationStack`.
  - This avoids nested home/document navigation that could leave iPhone portrait blank immediately after importer-open until the device was rotated.
  - The document split view no longer sets a redundant `Airframe` navigation title.
  - Log sidebar rows render selected state explicitly with Accent Color background and `.primary` text.
  - Verification passed: `swift test` in `Airframe/Packages/AirframeUI`; `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/airframe-ios-nav-fix-dd`; `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=macOS' -derivedDataPath /tmp/airframe-macos-nav-fix-dd`; manual iPhone simulator open-url screenshot `/tmp/airframe-ios-openurl-nav-fix.png`.
- Current document view architecture cleanup is implemented:
  - App-specific document views were moved out of `AirframeUI` and into the app target.
  - `DocumentHomeView` in `Airframe/App/Airframe/App` is the single document `NavigationSplitView` owner.
  - Document loading/opening/opened/failed states now change sidebar/detail content inside the same split view.
  - The old unused `DocumentSummaryView` wrapper and package-level document view file were removed.
  - App-specific view types no longer use the redundant product prefix; the home and document wrapper views are now `HomeView` and `DocumentView`.
  - `AirframeUI` now contains document/opening state models and number formatting, but no SwiftUI view types.
  - Verification passed: `swift test` in `Airframe/Packages/AirframeUI`; `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /tmp/airframe-ui-boundary-ios-dd-2`; `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=macOS' -derivedDataPath /tmp/airframe-ui-boundary-macos-dd`.
- Current SwiftUI preview coverage slice is implemented:
  - `AirframeUI` exposes debug-only `makeDebug...` factories for document/opening display state models.
  - `DocumentHomeView.swift` has previews for opened, scanning, empty, and failed document states.
  - `DocumentView.swift` has loaded and loading previews through minimal debug preview-state injection.
  - `HomeView.swift` has empty and opened-document previews through minimal debug preview-state injection.
  - Current `AirframeUI` sources still contain no SwiftUI view files.
  - Verification passed: `swift build` and `swift test` in `Airframe/Packages/AirframeUI`; iOS simulator Debug app build; macOS Debug app build; macOS Release app build.
- Current macOS log data-view structure slice is implemented:
  - The document sidebar now shows file identity/basic file facts and log selection only.
  - The selected log's main content is a `LogDataView` with `Overview`, `Table`, `Graph`, and `Spectrum` views.
  - View selection uses a top-toolbar segmented picker, persisted `@AppStorage`, and macOS menu commands with `Command-1` through `Command-4`.
  - Per-view files are grouped under `DocumentHome/Content/Overview`, `Table`, `Graph`, and `Spectrum`, with unique Swift basenames per Xcode target.
  - `LogContext` is injected through SwiftUI environment and can provide `AirframeLogSummary`, optional `DecodedLog`, `BlackboxAnalysisWorkspace`, issues, and progress.
  - `Overview` contains the existing summary/timing/status/issues sections.
  - `Table` and `Graph` have placeholder primary content plus a lower timeline split region.
  - `Table`, `Graph`, and `Spectrum` have placeholder macOS inspectors. The implementation now uses a custom macOS detail split instead of SwiftUI's native `.inspector`, because native inspector resizing could still collapse the document sidebar.
  - While a selected log is still scanning, the main data view shows centered progress instead of placeholder content.
  - macOS document windows now have minimum size 1180x660 points and default size 1280x760 points.
  - The sidebar list has a 300-point minimum width; log titles truncate in the middle and duration labels keep their intrinsic width so resize operations cannot squeeze rows down to unreadable fragments.
  - Inspector widths are persisted per data view and clamped to 300...460 points; the main data surface keeps a 560-point minimum before the inspector is shown. The custom split computes the content, handle, and inspector widths explicitly so child views cannot overflow left under the sidebar.
  - `AirframeDocumentOpenModel` retains decoded logs by ID so the app can build an analysis workspace for the selected log.
  - Verification passed: `swift test` in `Airframe/Packages/AirframeUI`; `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=iOS Simulator,name=iPhone 13 mini,OS=26.5' -derivedDataPath /tmp/airframe-log-views-ios-dd`; `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=macOS' -derivedDataPath /tmp/airframe-log-views-macos-dd`.
  - Layout hardening verification passed: `git diff --check`; `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=macOS' -derivedDataPath /tmp/airframe-layout-fix-macos-dd`; `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=iOS Simulator,name=iPhone 13 mini,OS=26.5' -derivedDataPath /tmp/airframe-layout-fix-ios-dd`.
  - Custom inspector split verification passed: `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=macOS' -derivedDataPath /tmp/airframe-custom-inspector-macos-dd-3`; `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=iOS Simulator,name=iPhone 13 mini,OS=26.5' -derivedDataPath /tmp/airframe-custom-inspector-ios-dd`.
  - Custom inspector overflow fix verification passed: `git diff --check`; `xcodebuild test -project App/Airframe.xcodeproj -scheme Airframe -destination 'platform=macOS' -derivedDataPath /tmp/airframe-inspector-width-macos-dd`.
- Current timeline slice is implemented (2026-07-12), six standalone commits:
  - `BlackboxAnalysis`: `motorAveragePercent` derived series + `AnalysisMotorOutputRange` resolver (`548adf3`).
  - `AirframeUI`: reusable Canvas `AreaGraph` with `GraphSample`/`GraphDomain`/`GraphProjection`/styles (`5bdc1fc`).
  - Retained `DecodedLogFlightInfo` in `AirframeDocumentOpenModel`, exposed through `LogContext.flightInfo` (`7f636a9`).
  - Per-log current position (main-frame µs) in `DocumentStateStore`/`DocumentStateRepository` (`6849b8c`).
  - `LogTimeline.Model` loader: 512-point min/max viewport reusing the retained index, event markers capped at 256 (`1fbbcf6`).
  - `LogTimeline` UI: area graph, event lines, draggable position line, per-window model cache (`2f1cccf`).
  - Verification passed per step: `swift test` in `BlackboxAnalysis` (16 tests) and `AirframeUI` (13 tests); `xcodebuild test` iPhone 13 mini / iOS 26.5 and macOS with isolated DerivedData; macOS Release build; simulator screenshots `/tmp/airframe-timeline-overview.png` and `/tmp/airframe-timeline-synthetic.png` (synthetic dynamic-motor fixture confirms area curve, event lines, and position line; the two small private staging logs are idle logs whose flat ~5% curve was CLI-verified as correct).
  - Drag interaction on macOS still needs a manual user check; simctl cannot send touches.
  - Follow-up fixes (2026-07-12, commits `6367ac1`, `2b4b155`):
    - Performance: series-table rows re-resolved `decodedLog.headerInfo` (full header reparse per access), re-sorted schema fields, and re-looked-up presentations per row. A 5.7 MB log took 23.6 s (release) for one motor-percent viewport; user saw minutes in Debug. `BlackboxAnalysisWorkspace` now builds one per-request `RowContext` (display context, motor field names, motor range, reader presentations, PID component fields); same log now 0.75 s. Verified with a /tmp release benchmark against two ~5.7 MB private logs.
    - Styling: timeline plot has 10 pt horizontal/bottom margins, 8 pt corner radius, and a per-log grid (10 equal duration segments vertical, every 20 percent horizontal) via `Style.gridLine` + model-derived `GraphGridStyle`.
    - `Localizable.xcstrings` auto-synced the new timeline string during builds; committed with the styling change.
  - Third follow-up round (2026-07-13, commit `d6cad5a`): the timeline beachball root cause was MainActor isolation, not data volume. `LogTimeline` conforms to `View` (MainActor protocol), so the static `makeModel` was isolated and the detached load task executed the entire model build (viewport + event decode) on the main thread. Verified by process samples before (100% build on `com.apple.main-thread`) and after (build on the cooperative pool) with the user's exact log. Builders are now `nonisolated`. Remaining known cost: the timeline still decodes the log twice more after the open scan (viewport pass + `events()` pass); a one-pass design (collect decimated series and event times during the open scan in Reader) is the proposed next slice, since the scan already visits every frame. Debug builds are ~20x slower on the parser; release total for a 5.7 MB log is roughly 2 s across all three passes.
  - Second follow-up round (2026-07-12, commits `7513711`, `64fc075`):
    - Beachball fix: `DocumentProgressRelay` forwarded one main-actor snapshot update per decoded frame during scanning; large logs queued hundreds of thousands of main-thread jobs and unbounded `stateHistory` growth. Relay now throttles to ~256 byte-delta-gated updates per log; regression test bounds applied updates for a 20k-frame log (`openModelThrottlesScanProgressUpdates`).
    - Timeline padding extended to all four sides (gap to the divider above).
    - User directive recorded in MEMORY: data preparation always off the main actor; throttle high-frequency progress into main-actor state.
- Current timeline range/collapse toolbar slice is implemented (2026-07-13):
  - Adds a compact toolbar above the shared Table/Graph timeline with icon-only In/Out buttons and current cursor time.
  - Persists active per-log ranges in document state and syncs them through the existing document-state repository/iCloud path.
  - Default range is full log; reversed bounds normalize silently; excluded timeline regions render dimmed.
  - Reduces the timeline graph height from 170 pt to 136 pt while keeping the toolbar at 34 pt.
  - Adds per-log collapse state stored as true-only `collapsedTimelineSegments` in the same synced document-state entry.
  - Keeps the toolbar visible while collapsed, hides the graph and In/Out buttons, disables matching `I`/`O` commands, and reclaims graph height.
  - Places the collapse chevron directly next to the `Timeline` title and uses tint-only hover feedback for toolbar icon buttons.
  - Verification passed: `xcodebuild test -project Airframe/App/Airframe.xcodeproj -scheme AirframeTests -destination 'platform=macOS'`; `xcodebuild test -project Airframe/App/Airframe.xcodeproj -scheme AirframeTests -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17'`.
- One-pass scan slice implemented (2026-07-13), five commits:
  - `3b61d63`: scan loop reads the summary time by field index instead of a per-frame name projection; release scan 0.77 s -> 0.54 s on a 5.7 MB log.
  - `046ac33`: `ReaderScanOverview` collected during `scan()` (decimated full-layout main-frame samples via adaptive stride, all event records with truncation flag, `Configuration.maxScanOverviewSampleCount` = 1024, hostile-input coverage). Scan overhead within noise (~5%).
  - `768ef17`: `BlackboxAnalysisWorkspace.overviewPoints(for:in:)` projects overview samples into series points (raw I-fields + motor-derived kinds; typed errors).
  - `dec5496`: timeline model is a pure overview projection — no viewport query, no event pass; timeline data cost 1.2 s -> 5.6 ms release on the 5.7 MB log; rendered output unchanged (test expectations identical).
  - `430969b`: document logs scan concurrently in a task group capped by `maxConcurrentLogTasks`; per-log results/progress apply against the latest snapshot.
  - Verification: `swift test` green in BlackboxReader (170), BlackboxAnalysis (21), AirframeUI (15), AirframeCLI (26); app `xcodebuild test` green on iPhone 13 mini / iOS 26.5 and macOS; simulator visual check of the timeline unchanged. Second benchmark log (Maya 5.8 MB): scan 0.60 s, projection 11 ms.
- Main-stream resync + defect marker slice implemented (2026-07-13), three commits:
  - `9992f3a`: initial FrameStream pending-anchor resync (rejected I frame becomes candidate; new `mainStreamResynchronized` issue; switch extensions in CLI/AirframeUI/snapshot helper). Its overly permissive ~762 s result on `…/1 Filter/LOG00002 Q700.BFL` is superseded by the later local-anchor refinement below.
  - `d14a8e1`: pipeline regression test — syncpoints/overview/range queries span a recovered gap.
  - `03f2c4f`: defects as timeline markers via `ReaderLogIndex.nearestMainFrameTime(atOffset:)`, `Model.Marker` with event/issue kind, orange `issueLine` style; simulator-verified with a synthetic 25 s gap log (two orange markers at the gap boundaries).
  - Verification: BlackboxReader 178 tests, all other package suites, app suites on iPhone 13 mini / iOS 26.5 and macOS, CLI checks on the real log.
- Main-stream recovery refinement completed (2026-07-13): `FrameStream` holds a rejected absolute `I` frame and its following main frames until two consecutive plausible `P` frames confirm it. Failed candidates restore committed history; `P` frames cannot establish a baseline. An untrusted out-of-window I/P sequence may be used only as decoder context while seeking another absolute I anchor; it is withheld from all consumers. A confirmed anchor must be temporally local (six normal time-jump windows). Full Reader suite passes (180 tests). Private Maya `LOG00002 Q700.BFL` validation recovers at `23.035302 s`, stops log 1 at `60.541099 s` (matching Upstream's ~01:00 end), and rejects the former false `693.490837 s` continuation; log 2 scans independently from `104.486025` to `127.427661 s`.
- Current Table view MVP slice is implemented (2026-07-13):
  - Adds per-log segment field selection state persisted through `DocumentStateStore` and `DocumentStateRepository.logFieldSelections`, with defensive restore and unchanged-skip behavior.
  - Adds reusable `DocumentHomeView.FieldSelection` and `FieldDescriptor` for catalog descriptors, validation, grouping, units, precision, and Core tuning defaults.
  - Adds `DocumentHomeView.Table.Model`, `ModelStore`, and bounded non-View loader logic that builds about 2,000 main-frame rows around the current position, reuses the retained scan index, and merges scan overview events as separator rows.
  - Replaces the Table placeholder with a dense SwiftUI data surface using a pinned header, horizontal column scrolling, lazy vertical rows, monospaced formatted values, current-row highlighting, viewport-center position updates, and the existing lower timeline region.
  - Replaces the Table inspector placeholder with grouped field checkboxes and a reset action; the last selected field cannot be removed.
  - Verification passed: `git diff --check`; `xcodebuild test -project Airframe/App/Airframe.xcodeproj -scheme AirframeTests -destination 'platform=macOS' -derivedDataPath /tmp/airframe-table-macos-dd`; `xcodebuild test -project Airframe/App/Airframe.xcodeproj -scheme AirframeTests -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17' -derivedDataPath /tmp/airframe-table-ios-dd`; iPhone simulator fixture screenshot `/tmp/airframe-table-native-single.png` showed real table rows, header, and current-row highlight.
- Table cursor/rebuild correction is implemented (2026-07-13):
  - Cursor changes inside the loaded table window now update only highlight/scroll state and do not rebuild `Table.Model`.
  - `Table.Model.shouldReload(for:)` returns true only outside `loadedRange`; a regression test covers range-edge positions.
  - Row-center preference handling no longer stores viewport height in SwiftUI state and defers position writes through a plain coordinator to avoid SwiftUI per-frame preference/onChange warnings.
  - Verification passed: `xcodebuild test -project Airframe/App/Airframe.xcodeproj -scheme AirframeTests -destination 'platform=macOS' -derivedDataPath /tmp/airframe-table-fix-macos-dd`; `xcodebuild test -project Airframe/App/Airframe.xcodeproj -scheme AirframeTests -destination 'platform=iOS Simulator,OS=26.5,name=iPhone 17' -derivedDataPath /tmp/airframe-table-fix-ios-dd`; iPhone simulator fixture screenshot `/tmp/airframe-table-fix-native-single.png`.
- Next concrete slice: visually exercise the Table view with full private logs and then continue with the minimal native chart prototype that consumes `BlackboxAnalysisWorkspace`, unless another security hardening topic is explicitly prioritized.
- Next concrete app slice after the shell: choose between native Swift Charts prototype, richer document metadata/issue UI, or remaining App Store project cleanup such as final icon and launch-screen/orientation metadata.
- Identify or collect representative Blackbox log fixtures:
  - Betaflight 4.4.3+ logs, which are the initial supported baseline.
  - Older Betaflight logs only when explicitly expanding compatibility.
  - Recent Betaflight 4.5/2025/2026 logs if available.
  - Logs with GPS.
  - Logs with multiple flights in one file.
  - Multiple separate logs that can be loaded as one import set.
  - Logs with dropped/corrupt frames.
- Use the user's private local logs as local-only fixture candidates:
  - `/Users/daniel/Library/Mobile Documents/com~apple~CloudDocs/Drohnen/Betaflight/Barney/Logs/6. IFT/LOG00002.BFL` (~33 KB)
  - `/Users/daniel/Library/Mobile Documents/com~apple~CloudDocs/Drohnen/Betaflight/Flip/Filter/Session 1/btfl_001.bbl` (~48 KB)
  - `/Users/daniel/Library/Mobile Documents/com~apple~CloudDocs/Drohnen/Betaflight/Puck/Tuning/1 Filter/1 Default/btfl_001.bbl` (~170 KB)
  - Do not commit these logs or derived fixture extracts without explicit approval.
- Current `BlackboxReader` package fixtures include synthetic `.bbfixture` files, native `.bbl`/`.bfl` files, and selected golden frame-stream snapshots under `Tests/BlackboxReaderTests/Fixtures/`. They are package-local and documented.
- Keep `blackbox-tools` as a possible later oracle, but do not add it now.
- Inspect the Betaflight firmware repository's `src/main/blackbox/` sources and unit tests as writer-side references for Blackbox log generation.
- Expand golden-output coverage for Betaflight `4.4.3+` before claiming more compatibility.
- Decision from scan slice: combined summary/index scanning is implemented as a per-log public API and benchmarked; no batch scan API yet because there are no consumers.
- Decide whether to create a new git repo/project or keep planning in this workspace first.
- Define the initial SemVer version and the xcconfig layout, including `Base.xcconfig` with `MARKETING_VERSION`.
- Define testing standards before implementation: fixture strategy, golden outputs, corruption cases, performance tests, and package-level API tests.
- Keep Swift package manifests on Swift 5.9 language mode and modern Swift Testing test targets.
- Add a later model/API plan for multi-file imports and multi-flight logs before implementing header/log splitting.
- Keep `Airframe/doc/blackbox-log-format.md` updated when implementing headers, predictors, encodings, frame types, and fixture findings.

## Completed: Indexed Table Chunk Cache (2026-07-13)

- Reader scan now exposes an I-frame-strided `ReaderMainFrameChunkDirectory`.
- Table loads resumable bounded chunks through a per-document LRU cache instead of repeatedly decoding 2,000-frame time windows.
- `BlackboxAnalysisWorkspace` can project selected raw and derived series directly from decoded chunks.
- Follow-up: profile cold and warm Table seeks with large private logs before changing chunk/cache defaults.

## Completed: Table Perceived-Performance Slice (2026-07-13)

- `BlackboxAnalysisWorkspace` resolves header info, reader catalog, display context, main-frame field names, motor fields/range, and the Analysis catalog once in `init`; `seriesCatalog` is a stored property. The former computed path reparsed the header per field per access. Release benchmark on a 6 MB Puck log: catalog access x3 `50 ms -> 0 ms`, `seriesTable(from: chunks)` x3 `66 ms -> 14 ms`, workspace init `0.9 ms`.
- `Table.Model` stores `frameRows` and sorted frame times; `nearestFrameRow(to:)` is a binary search; `Surface` computes the highlighted row once per body pass instead of per row (former O(n^2) per render).
- `MainFrameChunkCache` works per ordinal: partial hits decode only missing contiguous runs, identical concurrent loads share one decode task, `prefetch` warms ranges at utility priority and is superseded per log, eviction keeps a running frame total (LRU order fixed to ordinal order; `Dictionary.values` hash order previously broke it).
- `TableSurface` no longer keys its load task on the cursor: `Table.WindowPolicy.shouldReload` recenters the 2048-frame window only when the cursor's chunk index leaves the inner half of the loaded range, with no reload toward a log edge the range already touches. Cursor moves inside the window only update highlight/scroll.
- Stale-while-revalidate: after the first load, window swaps keep showing the current rows; a transient failed window keeps stale rows; after a swap the row nearest the cursor is re-anchored to the viewport center via stable row IDs.
- Scroll-quantization fix: the highlight-driven `scrollTo` fires only for external cursor changes (timeline), not for cursor writes caused by the user's own table scrolling (`ScrollPositionCoordinator.isExternalChange`).
- After each window load the surface prefetches 8 chunks per side; window (16) + prefetch (16) stay well under the 12,288-frame LRU cap.
- `Table.ModelStore` is removed; the chunk cache is the single cache. New tests: `MainFrameChunkCacheTests` (injectable loader closure), `TableWindowPolicyTests`, nearest-row binary-search cases in `TableModelTests`.
- Verification passed: `swift test` in `BlackboxAnalysis` (21) and `BlackboxReader` (180); `xcodebuild test` scheme `AirframeTests` on macOS and iPhone 17 / iOS 26.5.
- Note: `ruby xcodeproj` drops `name = Packages` from the `PBXFileSystemSynchronizedRootGroup`; restore it manually after every scripted project edit.
- Manual check still open: scroll feel with a large private log on macOS (no spinner after first load, no snap-to-row while scrolling, timeline jumps still recenter).
- Graph readiness: wide zoom uses the scan-overview projection, detail zoom uses this chunk cache; no separate LOD layer. Optional per-chunk min/max aggregation parked in BACKLOG.

## Questions To Resolve

- Should the first Swift prototype target macOS only for faster iteration, then iOS, or start as Universal immediately?
- What exact Swift Package boundaries should be used for parser, model, indexing, and analysis?
- Should efficient transformed/persisted log data be part of the first core design or introduced after profiling?
- What stable identity should distinguish imported files, Blackbox logs within a file, and individual flights/sessions?
- Which latest stable iOS and macOS deployment targets should be chosen when app targets are introduced?
- Should charts use Swift Charts, SwiftUI `Canvas`, Core Graphics, or Metal?
- Should Map use MapKit instead of OSM/Leaflet-style tiles?
- Should video sync/export be an MVP requirement or a later milestone?
- How important is compatibility with Cleanflight/INAV/EmuFlight compared with Betaflight-only first?
- Which local tool/MCP setup should be used once Swift implementation starts?

## Graph Setup Follow-up

- Done (2026-07-14): native Graph renderer implemented in five slices; see `PLAN.md` section "Graph Renderer Slices". Equal-height sections, per-field normalization into a shared [-1,1] section space (axis-hint ranges), cursor-centered window with scrub/tap/pinch, 12-color `SeriesPalette` with sticky per-field slots persisted in `GraphSetup`, hover/tap line highlight, and cursor value readout in the inspector rows of Table and Graph mode.
- Resolved (2026-07-15): `TableModelTests.testMakeModelBuildsFrameRowsAndEventRows` now expects the current deterministic width `84` for `Motor Avg` (`ceil(9 * 7.5) + 16`) instead of the stale `99`.
- Follow-ups done (2026-07-14): full-log-stable field scaling (overview-based ranges, pidSum/debug overview projections), app-global iCloud-synced "Show Graph Legend" toggle in the View menu (`AirframeGlobalSettings`), and event marker chips with inflight-adjustment captions ("Rate Profile = 1"); see PLAN.md "Graph Follow-up Slices".
- Done (2026-07-14): flight-mode flag-diff chips implemented as segmented per-flag states (only changed flags), the graph rendering relocated into the AirframeUI package, and macOS scroll/two-finger scrub added. See PLAN.md "Graph Package Relocation, Scroll-to-Scrub, Segmented Flag Chips".

## Risks

- Blackbox format compatibility across firmware versions.
- Lack of strong upstream parser tests.
- Performance for large logs on mobile devices.
- Recreating browser Canvas graph behavior natively may take more work than parser MVP.
## Spectrum View Slice (done 2026-07-15)

- Implemented in six standalone Airframe commits (`ff9a7fe`, `d3baddb`, `084e826`, `91503ff`, `f40021e`, `e542451`):
  - `BlackboxAnalysis/Spectrum`: namespace/constants/typed errors, sendable results, rate resolution from raw headers, `vDSP.DiscreteFourierTransform` wrapper with cached setups and the symmetric Hanning window, `AnalysisSpectrumAnalyzer` (frequency + vs-throttle/vs-RPM heatmaps), columnar `spectrumSamples` extraction.
  - `AirframeUI/Spectrum`: render model, `SpectrumSurfaceCanvas` with reserved overlay layer, pannable/anchored `SpectrumZoomPolicy` (1-5x), `SpectrumIntensity` (upstream zoomY semantics), off-main heatmap bitmap builder, `SpectrumScrollZoomView`.
  - App: two-section inspector (View: mode/intensity/Hanning; Field: grouped picker), per-document `spectrumSettings` persistence, surface with compute LRU, range-only debounce, display-only intensity task, pinch/pan/scroll/double-tap gestures, container above the shared timeline region.
  - Tests: Swift Testing suites in BlackboxAnalysis (FFT scaling pinned by a bin-aligned sine, rate, analyzer, heatmap binning, sample source) and AirframeUI (zoom policy, intensity, heatmap image), XCTest app suites (settings storage/store roundtrip, model/cache), and an iOS XCUITest for the spectrum view and inspector controls.
  - Verified against the real `Logs/btfl_007.bbl`: max-noise 307.1 Hz matches the reference analyser's 307 Hz; full-log FFT 5-8 ms, extraction ~850 ms off-main.
- Known pre-existing failure (NOT from this slice, confirmed on baseline `8616237`): `TableModelTests.testMakeModelBuildsFrameRowsAndEventRows` expects column width 99 for "Motor Avg" but gets 84 (short-label drift). Needs a separate look.
- Deferred spectrum views are recorded in `BACKLOG.md`.

- Spectrum analysis and video export can expand scope quickly.
- External dependencies must not be introduced without explicit user approval, so any dependency proposal needs justification and an approval step.
- Version drift is not allowed: Swift Packages and Xcode targets must keep the same SemVer version, with Xcode targets inheriting `MARKETING_VERSION` from `Base.xcconfig`.

## Tooling Candidates

Useful tools or MCP servers to consider once implementation starts:

- Xcode itself is only needed in individual special cases; prefer CLI-first workflows.
- `xcodeproj` for Xcode project file inspection or edits.
- `swift build` and `swift test` for Swift Package work.
- `xcodebuild` for Swift packages and app schemes when needed.
- `xcrun simctl` for simulator lifecycle, install, launch, screenshots, and logs.
- When running simulator-related `xcodebuild`, do not pipe output to `grep`; write robust logs, wait for completion, then inspect the log files.
- Apple's built-in Xcode MCP server, if the installed Xcode version supports it and a task specifically benefits from it.
- XcodeBuildMCP for build, test, simulator, and device workflows through MCP if CLI-only workflows become cumbersome.
- SourceKit-LSP for Swift semantic indexing, diagnostics, and navigation.
- SourceKit-LSP-based MCP servers such as SwiftLens or Swift MCP Server, if they prove reliable locally.
- Standard CLI tools remain important: `xcode-select`, `swift-format`, and `swiftlint` if adopted.
- For UI verification, simulator screenshots and XCTest/UI tests will matter more than generic web tooling.

## Step Response with multi-log comparison (implemented 2026-07-18, uncommitted)

- `BlackboxAnalysis/StepResponse`: `AnalysisStepResponse` namespace (Input/Settings/RateClass/AxisResult with peak + time-to-50% latency, typed errors with counts), `AnalysisStepResponseCalculator` porting PIDtoolbox `PTstepcalc.m` (2 s Hamming windows, >=20 deg/s input mask, spectra normalized by window length, Wiener regularization 1e-4, MATLAB-`smooth`-style 10 ms moving average, cumsum, settling-band QC min in (0.5,1] / max in (1,2), subsample factor 9 = PTB default UI value 3 x 3), `AnalysisStepResponse.FFT` (complex forward/inverse `vDSP.DiscreteFourierTransform`, power-of-two padding), `stepResponseInput` sample source (one aligned `mainFrameFields` pass over `setpoint[axis]` + `gyroADC[axis]`, spectrum rate resolver shared).
- `AirframeUI/StepResponse`: `StepResponseRenderModel` (panes/traces with per-trace sample interval and preformatted detail) and `StepResponseSurfaceCanvas` (stacked panes, emphasized 1.0 reference line, PTB-style per-trace info block with n/latency/peak, spectrum highlight semantics: non-highlighted opacity 0.22).
- App: `LogViewSelection.stepResponse` (cmd-5, symbol `stairs`), feature folder Container/Surface/Model/Inspector/Settings, `StepResponseTraceID` (`document(segmentIndex:)`/`reference(fileIdentity:segmentIndex:)`, storageKey codec), document-wide `StepResponse.ViewState` (settings + hidden-trace set) persisted as versioned `stepResponse` entry field (deliberately NOT in per-segment `LogAppearance`/presets: the view overlays multiple logs), `DocumentLogAccess` environment value (multi-log access; `LogContext` unchanged), `StepResponseHighlightState` owned by `DocumentHomeView` (sidebar and detail live in different split-view columns), sidebar trace rows (stable `SeriesPalette` color = segmentIndex, checkmark visibility toggle, macOS hover highlight, three-line R/P/Y tune grid from new `AirframeLogSummary.tune`/`LogTuneSummary` reading `rollPID`/`pitchPID`/`yawPID` + `ff_weight`), `ReferenceLogStore` (session-only, max 4 files, per-file `AirframeDocumentOpenModel`, sticky reference color slots, typed `AttachError`), References sidebar section (+ fileImporter, drag&drop of .bbl/.bfl onto the list, remove prunes hidden traces and slots), reference in/out ranges read via `DocumentStateRepository.timelineRange(forIdentity:segmentIndex:)` from the same synced entry the file uses as its own document.
- Tests: 113 BlackboxAnalysis package tests (synthetic first-order/second-order systems recover analytic responses; steady-state tolerance 0.08 on first-order due to Hamming/regularization bias, mask/rate-class/QC/error/cancellation cases, sample-source alignment) and 223 app tests including new `ReferenceLogStoreTests` (attach/duplicate/unreadable/remove/slot stability); all green on macOS.
- Verified in the running app with the Damping logs: three stacked panes with per-trace metrics, inspector settings, sidebar color dot + tune matrix matching the header, References section present. Reference attach exercised at unit level; interactive open-panel flow still to be user-verified.
- Rework after user review (2026-07-18, same day): references are available and selectable in ALL view modes. New `DocumentHomeView.LogSelectionID` (`document(LogID)` / `reference(fileIdentity:summaryID:)`) drives the sidebar selection; this also fixed a data-mixing bug where two attached references rendered identical rows because every file's first segment shares `LogID(source 0, segment 0)` and SwiftUI List recycled rows with duplicate identity. Selecting a reference log injects the reference file's own `DocumentStateStore` (from `ReferenceLogStore.stateStore(for:)`, persisted on remove/close/terminate) as `\.documentStateStore` for the whole split view, so ranges/presets/view settings behave exactly as in the file's own document window; the new `\.windowStateStore` environment key always carries the window's primary store and backs everything window-scoped (Step Response settings + hidden traces, reference pruning). The Step Response trace list (color circle, PID tune, visibility toggle, hover highlight) moved from the left sidebar into the right inspector above the settings, mirroring the field/filter lists of the other inspectors; the left sidebar shows plain selectable log rows in every mode. Reference trace ranges now read live from the reference's state store instead of the raw repository entry.

## Refinement: Main Document as UI master + per-log range + router (implemented 2026-07-19, uncommitted)

- Main Document is the single master for all view UI settings; reference logs supply data only. New `LogViewStateStore` router (`App/Airframe/App/LogViewStateStore.swift`, a value type, Equatable by `===` on its two store refs) is the value carried by `\.documentStateStore`. It wraps `master` (window store) and `active` (selected log's store: window store for document logs, `ReferenceLogStore.stateStore(for:)` for reference logs) and forwards each member: settings/presets/step-response/view-mode/graph-zoom -> master; timeline in/out range, current position, timeline collapse, graph viewport -> active. Views are unchanged (same `stateStore.<member>` calls, key path `\.documentStateStore`); `DocumentHomeView` builds the router, `DocumentView` injects a degenerate `LogViewStateStore(stateStore)`. `\.windowStateStore` stays the master for the multi-log Step Response consumer. Per-log unsupported fields/modes are dropped at render by the existing catalog-resolution helpers (resolved against the selected log's `context.workspace.seriesCatalog`), so nothing is disabled globally.
- Zoom is master (shared time-span across logs), current position is per log (scrub each log to its comparable spot, switch at fixed zoom to compare).
- Fixed a proven cross-log cache collision: all per-window caches (LogTimeline.ModelStore, GraphModelCache, MainFrameChunkCache, GraphPreparedSeriesCache) key by `LogID`, and reference logs share `LogID(source 0, segment 0)` with the document's first log, so a reference rendered the document's cached timeline/graph/table and `.onChange(of: summary.id)` did not fire on doc<->ref switch. Added `LogContext.cacheLogID` (window-unique: document logs keep their `LogID`; reference logs get a remapped `SourceID` from `ReferenceLogStore.cacheSourceID(for:)`, offset 1_000_000+, session-scoped for in-memory caches only). All cache identities and the per-view `.onChange` triggers now use `cacheLogID` instead of `summary.id`/`workspace.decodedLog.id`. Persisted per-log state stays keyed by `summary.id.segmentIndex`.
- Reference in/out now works: timeline range routes through the router to the reference's own `DocumentStateStore` (keyed by contentIdentity), persisted via `ReferenceLogStore.persistAll()` on close/terminate/background. `ReferenceLogStore` gained injectable `defaults`/`cloudStore` for isolated tests.
- Removed the Step Response inspector axis toggles and `Settings.shownAxes` (+ its `Storage` `ax` key, ignored on decode); the surface always renders roll/pitch/yaw.
- Spectrum mode persistence: the chain was already correct (proven by `SpectrumSettingsTests`); the observed non-persistence was writes landing in the discarded reference store, fixed by routing settings to master. Added a router-level assertion.
- Tests: new `LogViewStateStoreTests` (settings->master, per-log->active, spectrum-mode persist+reload, degenerate master===active), extended `ReferenceLogStoreTests` (reference in/out persists to its own entry via injected defaults). 232 app tests + 113 package tests green.
- Verified in the running Release app on 050.BFL: Graph shows master fields, Step Response renders three panes (roll n=28 peak 1.11, pitch n=47 peak 1.24, yaw n=4 peak 0.95) with the inspector Logs trace list (color dot + PID matrix + toggle) and no axis toggles. Note: on first open a transient "no analysable samples" can flash while the scan/auto-range is still settling; it self-heals once flight data is ready (the compute cache is keyed by range, which changes as flightInfo loads). Interactive reference attach could not be driven by automation (SwiftUI fileImporter ignores synthetic key events; documented in TOOLING) - the reference master-settings/in-out/divergent-color behaviors are covered by unit tests and still want a manual pass.

## Shared stacked-pane chart frame (implemented 2026-07-19, uncommitted)

- New `AirframeUI/Charts/StackedPaneChartFrame.swift`: reusable struct owning the stacked-pane frame geometry and drawing shared by both stacked canvases (layout inset/plot/paneHeight/paneRect, background 0.06, per-pane value grid + labels + pane title, full-height shared vertical grid via caller-supplied `VerticalTick` list, pane separators, edge/bound labels, `yPosition`). Configured per render with value range, value step, a value-label closure, and an axis sample label for inset sizing. The domain (X) axis stays per-canvas (spectrum nonlinear zoom + adaptive `niceFrequencyStep`; step response linear time, fixed 100 ms) and each canvas keeps its own reference line (spectrum: vertical 100 Hz solid brighter; step response: horizontal dashed 1.0), traces, and interaction.
- `StackedSpectrumSurfaceCanvas` (+ its `StackedSpectrumCrosshairChipOverlay`) and `StepResponseSurfaceCanvas` both render their frame through it. Spectrum output is unchanged by construction (every constant/formula was lifted verbatim from the spectrum canvas as the golden reference); the crosshair chip now derives inset/plot/paneHeight/paneRect from the same frame so its geometry is provably identical to the main canvas.
- Step Response fixes via the unification: the shared Y range is now snapped up to the 0.5 grid step in `StepResponseModel.makeRenderModel` (`maximumValue = min(max(ceil((peak+0.15)/0.5)*0.5, 1.5), 2.0)`; old `1.6` floor became `1.5`), so the topmost gridline sits exactly on each pane's top edge (seamless stack, no empty band, pane title now inside/below the top edge like spectrum). Added X corner labels `0 ms` / `500 ms` matching spectrum's `drawEdgeLabels`.
- Verified: AirframeUI builds, 89 package tests green, Airframe macOS app builds. Value-range rounding checked numerically (peaks 1.29 -> 1.5, 1.9 -> 2.0, both 0.5-aligned). Visual parity in the running app still wants a user pass.

## Step Response sidebar refinements + reference log dedup/limit (implemented 2026-07-19, uncommitted)

- Sidebar trace rows (`StepResponseInspector.swift`): the main-document label now carries the file name like references (`"<sourceName> · <title>"`, built in `StepResponseModel.traceSources`). Each PID axis row shows its analysis window count `n=<usedWindowCount>` right-aligned in the trace color; the count is surfaced from the surface's private compute state via a new per-window `@Observable StepResponseResultsState` (mirrors `StepResponseHighlightState`, injected in `DocumentHomeView`), which `StepResponseSurface.compute()` fills with a slim `[outcomeKey: Int]` map. Row layout is one `Grid`: axis letters R/P/Y sit under the color circle, P/I/D/F values under the title. PID values that are constant across all logs render `.secondary`; values that vary between logs render in the trace color (`StepResponse.tuneVariance(of:)`, distinct-set-count>1 over `compactMap(\.tune)`, single log => all constant). A single `PIDColumnHeader` legend row ("P I D F") is shown once at the top of the Logs section, aligned to the fixed value columns via shared `PIDColumnMetrics` (axis col 10, spacing 8, value width 22, value spacing 6).
- Reference logs (`ReferenceLogStore.swift`): a file already open as the main document can no longer be attached as a reference. `ReferenceLogStore` gained `mainDocumentIdentity` (set in `DocumentView.init` from `document.contentIdentity`); `attach` rejects a candidate whose `LogDocument.contentIdentity(for:)` matches it with a new typed `AttachError.alreadyMainDocument(fileName:)`. Comparison is content-based, so the same file opened via a different security-scoped URL is still caught.
- `maximumReferenceLogs` raised 4 -> 8 (uniform on macOS and iOS, user decision). Step Response caches bumped to fit main + 8 references x 3 axes without LRU thrash: `WorkspaceCache` 6 -> 12, `ComputeCache` 36 -> 72. Note: reference decoded logs are retained eagerly, so 8 references roughly doubles the previous resident-memory ceiling. `SeriesPalette` has 12 colors and wraps past index 11 (no crash; hues can repeat only if references are multi-segment beyond ~12 total traces). No UI (the + button was never disabled) or persistence change needed.
- Tests: new `StepResponseTuneVarianceTests` (5, all green) and `ReferenceLogStoreTests.testAttachingTheMainDocumentIsATypedFailure` (7 total in that suite, green). App builds on macOS. Suitable tuned test logs (with PID/setpoint data) live at iCloud `Drohnen/Betaflight/Maya/Tuning/Flights/2 Damping` (the bundled UITest fixtures have no PID header).

## Step Response multi-log parallelization (implemented 2026-07-19, uncommitted)

- Problem: computing the Step Response for several logs (main document + up to 8 references, 3 axes each) was slow and used only one CPU core. The bottleneck was purely the UI driver `StepResponseSurface.compute()`, whose `for entry in missing { await activityCounter.compute { computeAxisResponse(...) } }` loop awaited each trace/axis unit before starting the next. The algorithm (`AnalysisStepResponseCalculator`, `Sendable`, pure over its inputs) was already parallelization-ready.
- Fix (single file, `StepResponseSurface.swift`): the sequential loop is replaced by a `withTaskGroup` fan-out with **one task per trace** (new order-stable `groupByTrace` helper collapses the flat trace×axis work list). Each task creates/reuses the trace's `BlackboxAnalysisWorkspace` once and computes its 3 axes sequentially inside a single `activityCounter.compute { ... }` call, returning `(traceKey, workspace, [(key, outcome)])`; the tasks run in parallel across traces, so parallelism scales with the number of logs (the user's scenario). The cooperative pool caps real parallelism at the core count, so no manual chunking/semaphore.
- Invariants preserved: every unit still routes through `activityCounter.compute` (Processing Activity Rule; `activeCount` now legitimately >1, spinner correct); the non-Sendable `workspaceCache`/`computeCache` `@State` structs are mutated only on the main actor. Debounce/fingerprint/`loadState`/`results.setWindowCounts` unchanged. `computeAxisResponse` and the algorithm untouched, so `n`/peak/latency are identical by construction (only wall-clock + core use improve).
- CRITICAL regression + fix (same day): the first cut stored all group results in one batch AFTER the task group finished, gated behind `guard !Task.isCancelled else { return }`. When opening a folder, references attach and each log's range settles one by one as `flightInfo` loads, so `surfaceKey` changes repeatedly and `.task(id:)` cancels the in-flight `compute()` before the batch store ran. Every cancelled run discarded ALL its work → the compute cache never filled → the view livelocked, recomputing 8 logs from scratch forever ("never finishes"). Fix: store each trace's results incrementally inside the `for await computed in group` loop (which runs on the main actor), with no cancellation gate on the store — exactly the incremental-progress behavior the pre-change sequential loop had. Completed traces are cached even if the task is later cancelled, so successive restarts do strictly less work and converge monotonically. Storing a still-valid (key-matched, range-included) result is always correct; stale keys just sit in the LRU.
- Verified: macOS Debug build clean (no new warnings from the change; the pre-existing Swift-6-only `captured var 'outcomes'` warning on the unchanged `makeRenderModel` closure remains, matching the `SpectrumSurface` sibling). All 242 app tests green. Runtime: opening a Damping `.BFL` scans + renders through the modified path and the process converges to 0% CPU (no livelock); heavy parallel work was observed at ~200% CPU (multi-core in use). The exact folder-open multi-log flow could NOT be driven headlessly (NSOpenPanel/fileImporter ignore synthetic key events; documented in TOOLING), so the multi-log convergence rests on the incremental-store logic matching the previously-working code; wants a manual user pass with the folder.

## Step Response 1+N further speedups: parallel reference load + single-pass extraction (implemented 2026-07-19, uncommitted)

- Follow-up after the user reported 1+7 logs still slow despite multi-core use. Two independent serial costs remained, neither in the FFT kernel itself.
- (A) Reference loading was serial. `DocumentView.attachPendingFolderReferences()` looped `for reference in pending { await referenceLogStore.attach(...) }`, and each `attach` does a full whole-log `flightInfo`/`scan` (decodes every frame). A folder reference is a single-log file, so each scan uses one core -> 7 references decoded one-after-another, single-core, while other cores sit idle. Fix: new batch `ReferenceLogStore.attach(references:)`. Registration (limit/dedupe/main-doc rejection/append) runs synchronously on the main actor first, so display order stays folder order; then the files' `openModel.load(data:)` runs concurrently in a `withTaskGroup` whose child closure captures only Sendable locals (`openModel` is a `@MainActor` class, `data` is `Data`) — NOT `self` or the non-Sendable `DocumentStateStore`, so no Sendable warnings. The per-file automatic-range pass (`applyAutomaticRange`, touches per-file state via `self`) runs sequentially after the loads as a smaller tail. `DocumentView` now calls the batch method inside the existing `activityCounter.track { }`. NB: `ReferenceLogStore` could not simply be marked `@MainActor` because `ReferenceLogStoreKey.defaultValue` is a nonisolated `EnvironmentKey` static.
- (B) Step Response extraction re-decoded the range 3x per log. `mainFrameFields` decodes the whole frame per row regardless of requested field count (field selection is pure projection afterwards), and `computeAxisResponse(axis:)` called `stepResponseInput(axis:)` once per axis -> the same main-frame range was iterated 3 times per log. Fix: new `BlackboxAnalysisWorkspace.stepResponseInputs(axes:)` extracts every axis's setpoint/gyro in ONE `mainFrameFields` pass (union of field names), then builds each axis's buffers with the same per-axis row skipping as before. Existing `stepResponseInput(axis:)` was refactored to share the same `resolveAxisFields`/`decodeMainFrameFields`/`buildInput` helpers, so single- and multi-axis paths are byte-identical. New app-side `DocumentHomeView.StepResponse.computeAxisResponses(axes:)` does rate resolution + the one shared extraction + the calculator per axis, returning `[Int: Result<AxisResult, Error>]` (per-axis failure isolation preserved; an unavailable axis reproduces the exact `stepResponseInput` error, which throws before any decode). `StepResponseSurface`'s per-trace task calls it once instead of looping `computeAxisResponse` per axis.
- Identical results by construction: for a given axis the union pass includes the same rows (a sample is emitted when any requested field is present; per-axis buffers still require BOTH that axis's fields), and values are read by field name from the shared samples. New parity tests (`AnalysisStepResponseSampleSourceTests`): multi-axis == single-axis per axis; multi-axis omits axes the log lacks. `stepResponseInput`/`computeAxisResponse` kept for tests/back-compat.
- Measured (Debug build, so absolute times are inflated; ratio is the point): scanning the 6 Damping reference logs serially = 69.2s vs. parallel = 39.5s -> **1.75x** on the load phase. It is not ~6x because the largest file (100.BFL, 16 MB) dominates the parallel wall time (parallel ~= longest single scan). Extraction (B) additionally removes ~2/3 of the per-log step-response decode; FFT compute is unchanged.
- Verified: macOS Debug app build clean (no new warnings). 242 app tests + 115 BlackboxAnalysis package tests (2 new parity tests) green. The end-to-end folder-open wall-clock improvement still wants a manual user pass (the folder picker cannot be driven by synthetic events).

## Open a folder of logs (implemented 2026-07-19, uncommitted)

- New feature: open a folder and load the first blackbox log (Finder name order, `localizedStandardCompare`) as the main document plus the next logs as reference logs, capped at `FolderLogImport.maximumLogs = 8` total (1 main + up to 7 references). Filters `bbl`/`bfl`, ignores other files.
- Architecture: a `DocumentGroup` document carries no URL, so the newly opened window cannot be handed sibling files directly. `FolderLogImport.prepare(folder:)` (new `ReferenceLogs/FolderLogOpen.swift`) reads all logs while it holds the picked folder's security scope, stashes the reference bytes in the app-level `PendingReferenceLogs.shared` keyed by the main log's `contentIdentity`, and returns the main URL+data. `DocumentView`'s existing `.task(id: document.id)` drains `PendingReferenceLogs.take(forMainIdentity:)` after the main load and calls the new `ReferenceLogStore.attach(data:fileName:)` per reference (best-effort; the shared attach path enforces the 8-log limit, dedupe, and the `alreadyMainDocument` rejection). Attaching by data (not child URLs) keeps it valid after the folder scope is released, which matters on always-sandboxed iOS.
- Entry points: macOS File > Open Folder… (Cmd+Shift+O) in `LogViewCommands` via `NSOpenPanel(canChooseDirectories)` -> `NSDocumentController.openDocument(withContentsOf: main)`; iOS `HomeView` "Open Folder" button + `.fileImporter(allowedContentTypes: [.folder])` -> `LogDocument(sourceName:data:)`. The join key is `contentIdentity` (recomputed from the main bytes), the only identity a DocumentGroup window knows at init.
- Tests: new `FolderLogImportTests` (name sort picks the lowest name as main; non-log files ignored; cap at maximumLogs; nil for a folder without logs) and `ReferenceLogStoreTests.testAttachingTheMainDocumentIsATypedFailure`; 10 tests in those two suites green. macOS and iOS (generic device) both build.
- Not yet verified interactively: the macOS NSOpenPanel/go-to-folder step ignores synthetic key events (see TOOLING), so the panel click-through and the multi-log varying-color sidebar want a manual pass. The `2 Damping` iCloud folder (7 damping logs) is the natural manual test.

## Fix: automatic timeline range for reference logs + Auto button (implemented 2026-07-19, uncommitted)

- Bug: reference logs never got an automatic in/out range on open, and the timeline "Auto" button did nothing when a reference log was selected. Two proven root causes: (a) the `AutomaticTimelineRangeAction` was built in `DocumentView` and hard-wired to the MAIN `openModel`/`stateStore`, so `replaceRange` (Auto button) read/wrote the wrong store when a reference was active; (b) `ReferenceLogStore.attach` only loaded the model and never ran an auto-range pass (the only initial pass, `DocumentView.task`, covers the main document only).
- Refactor: extracted the range-derivation core into `DocumentHome/AutomaticTimelineRangeApplier.apply(logs:decodedLog:flightInfo:store:activityCounter:replacingExisting:segmentIndexFilter:respectGlobalSetting:)`, parameterized over any `(logs, providers, store)` triple (was `DocumentView.applyAutomaticTimelineRanges`, now deleted). Range detection unchanged (`BlackboxAnalysisWorkspace.automaticTimelineRange(using:)`).
- Fix (a): the `AutomaticTimelineRangeAction` is now built in `DocumentHomeView.automaticRangeAction(context:)` bound to the SELECTED log (`selectedLogContext` + `activeLogStateStore`), so both `applyMissingRanges` (post-reset reapply) and `replaceRange` (Auto button) target the active log's own store — main or reference. `DocumentView` no longer injects the action.
- Fix (b): `ReferenceLogStore.attach(data:fileName:)` runs the applier against the reference's own `stateStore(for:)` after load, guarded by `AirframeGlobalSettings.shared.isAutomaticTimelineRangeEnabled` and a `ReferenceLogStore.activityCounter` (injected by `DocumentView.init`; nil in tests -> no pass). Covers all attach paths (folder drain, drag-drop, importer). Uses `replacingExisting: false`, so a reference that already has a stored range from a prior session keeps it.
- `DocumentView` keeps the main-document initial pass in `.task` (now delegating to the applier). Tests: new `AutomaticTimelineRangeApplicationTests.testApplierWritesRangeToTheProvidedStore` proves the applier writes to whichever store it is given (the crux of both fixes); existing auto-range/reference/router suites stay green (18+). macOS and iOS build.
- Not driven interactively (NSOpenPanel/fileImporter automation limits, see TOOLING): the reference range on folder-open and the Auto button on a selected reference want a manual pass with the `2 Damping` logs.

## Stable macOS main menu (implemented 2026-07-19, uncommitted)

- Deleted the entire imperative menu patching: `AirframeFileMenuPolicy` (0.25 s repeating timer + `didBeginTracking` observer + English title matching) in `AirframeApp.swift` and the `positionNavigationMenu`/`applyToNativeFileMenu` calls plus `asyncAfter(0.5)` in `DocumentView.onAppear`. The timer racing SwiftUI's menu rebuilds was the source of the first-open flicker.
- The Navigation menu now stays at SwiftUI's default `CommandMenu` position between View and Window (user-approved; the force-move before View is gone).
- Read-only File menu (final approach after two abandoned ones): `ReadOnlyFileMenuPolicy` (`App/ReadOnlyFileMenuPolicy.swift`, macOS-only, installed from `AirframeApp.init`) keeps ALL native File items and clears the action of write-family items the moment AppKit posts `NSMenu.didAddItemNotification`/`didChangeItemNotification` for them (selector set: `saveDocument:`, `saveDocumentAs:`, `duplicateDocument:`, `renameDocument:`, `moveDocument:`). An item without an action fails auto-validation → rendered disabled, key equivalent inert. Event-driven, no polling, no title matching, survives SwiftUI rebuilds. `newDocument:` needs no handling: the viewing-only DocumentGroup disables New natively (verified). `revertDocumentToSaved:`/`browseDocumentVersions:` are cleared only for items in File SUBmenus (`menu.supermenu?.supermenu != nil`, i.e. the lazily populated Revert To children): clearing the hidden top-level Revert item's action suppresses AppKit's whole Revert To submenu AND the Share item, which anchor on that action (verified empirically).
- Abandoned approach 1 (per plan): custom `NSApplication` subclass via `NSPrincipalClass` overriding `target(forAction:)`. SwiftUI installs its own `AppKitApplication` and never instantiates the plist principal class; see TOOLING.
- Abandoned approach 2: fully declarative `CommandGroup(replacing: .newItem/.saveItem)` with disabled lookalike items. Worked in a clean launch but hit the long-standing macOS bug where replacing `.saveItem` corrupts the system Open Recent item into a dead "NSMenuItem" placeholder (user screenshot; Apple forums thread 749198, Eclectic Light 2024-05-16; still present on macOS 26.5). Replacing also drops native Close/Close All/Share/Revert To. The interim Close/Share re-adds and the `\.airframeDocumentFileURL` focused value were reverted with it.
- Loading-time menu blinking fixed: `DocumentHomeView.LogViewCommandState` is now Equatable with a `Capabilities` value (logID, selection, canSelectView/…/canResetFileSettings) compared by `==` and an `Actions` closure payload excluded from equality, so per-render republishes from `LogDataView` no longer invalidate the Commands body. `DocumentHomeView.detail`'s no-context branch publishes a constant `LogViewCommandState.unavailable`, so exactly one focused-value publisher exists per window and the only menu update happens once at load completion.
- Verified (temporary in-app File-menu dump to the sandbox tmp dir, since removed; app launched via `open -n` with a fixture log, self-activated, `menu.update()` forced validation): New naturally disabled; Save/Save As/Duplicate/Rename/Move To disabled via cleared actions; Open/Open Recent/Open Folder…/Close/Close All native and enabled; Revert To submenu and Share present; no "NSMenuItem" ghost; top-level order Airframe/File/Edit/View/Navigation/Window/Help. macOS + iOS builds clean; 115 + 14 tests green. Wants a short manual pass: Revert To submenu children grey out when the submenu is first opened (lazy population path), and the visual no-flicker check during a large-log load.
