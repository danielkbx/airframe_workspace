# Airframe Investigation Plan

## Current App Store Sandbox And iCloud State Slice

- macOS App Sandbox is enabled with read-only user-selected-file access. Airframe does not persist document URLs, security-scoped bookmarks, or file metadata; it remains a read-only byte-backed viewer.
- iCloud Key-Value Storage mirrors only the `DocumentStateRepository` per-document LRU buffer. Global fallback preferences remain local.
- Repository merge is per document identity using `updatedAt`; remote wins timestamp ties, invalid remote entries are ignored, and the existing 50-entry LRU cap remains in force.
- iCloud state changes never update a currently open document window. They update only the repository cache used by subsequent document windows.
- macOS UI-test fixtures avoid arbitrary external paths and use fixture bytes staged in the app's temporary sandbox directory before native document opening. The local macOS XCUITest host still launches the app as Running Background, so that test remains opt-in/skip-by-default pending host repair.
- macOS never restores document windows after quit or at login. Reopening an already-running, window-free app presents the native Open dialog; closing the last document leaves the app window-free.

## Current Timeline Visualization Slice (2026-07-12)

The first real visualization is implemented: the shared lower timeline in Table and Graph. Six standalone commits (`548adf3`, `5bdc1fc`, `7f636a9`, `6849b8c`, `1fbbcf6`, `2f1cccf`) cover the `motorAveragePercent` derived series with `AnalysisMotorOutputRange`, the reusable Canvas `AreaGraph`/`GraphProjection` layer in `AirframeUI`, retained per-log `DecodedLogFlightInfo` exposed through `LogContext`, the per-log current position (main-frame µs) persisted through `DocumentStateStore`/`DocumentStateRepository`, the 512-point timeline model loader with capped event markers, and the interactive timeline UI with a per-window model cache. Package and app test suites passed per step on iOS and macOS; rendering was verified in the iPhone simulator with a synthetic dynamic-motor log. Remaining manual check: drag feel on macOS. Follow-ups are parked in `BACKLOG.md` (indexed event access, metric switcher, Table/Graph position consumers).

## Current Phase

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

1. Replace the `Table`, `Graph`, `Spectrum`, and timeline placeholders incrementally with real data surfaces backed by `BlackboxAnalysisWorkspace`.
2. GPS optional-frame alignment and GPS distance/azimuth/local coordinate derived series.
3. Additional CLI backlog commands such as `stats`, `summary`, `frames`, and `derived` when approved.
4. Gyro scaling and attitude estimate derived series.
5. Optional coverage-guided fuzzing setup for parser/reader security.

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
