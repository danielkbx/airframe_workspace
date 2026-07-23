# Native Swift Architecture Notes

Project/app name: Airframe.

Product subtitle: A Blackbox Log Analyzer.

## Preferred Shape

- `BlackboxAnalysisWorkspace.motorAnomalies(using:)` is the exact indexed full-log seam for observed per-motor RPM-loss intervals. `AnalysisMotorAnomaly` carries zero-based motor index plus main-frame start/end times. The app caches it in `LogTimeline.Model`; Timeline merges ranges only for red background bands and Graph projects original intervals to start/end generic `.anomaly` markers. `GraphSurfaceCanvas` and `GraphMarkerChips` stay dependency-free.

Document-wide field selection is app-owned UI state: one ordered list of `AnalysisSeriesID.rawValue` values is shared by Table and Graph, while each active log resolves only IDs it supports. The reusable picker and its pure selection model live in the app target; `BlackboxAnalysis` remains responsible only for catalogs and series data.

Use a package-oriented architecture:

- `BlackboxCore`: pure Swift package for IO-free parser primitives: byte streams, headers, frame definitions, field encodings, predictors, and one-frame payload decoding. It intentionally has no logging dependency.
- `BlackboxReader`: pure Swift package for source-file import, bounded header preview, log segment assembly, compatibility gating, lazy decoded-log access, full frame-stream iteration, event decoding, and corruption recovery. Depends on `BlackboxCore` and `Logging`.
- `BlackboxIndex`: optional future Swift package or Reader layer for lightweight summaries, syncpoint indexes, time ranges, chunk access, and efficient seeking.
- `BlackboxAnalysis`: Swift package for app-facing series composition, display-scaled raw values, derived signals, and later tuning-oriented analysis. Depends on `BlackboxReader` and `Logging`.
- `AirframeCLI`: Swift package for command-line log inspection, validation, filtering, CSV export, JSON/NDJSON output, and shell completion. It contains `AirframeCLIKit` for testable CLI logic and a thin `AirframeCLI` executable target for the `airframe` command. Depends on `BlackboxReader`, `Logging`, and the approved `apple/swift-argument-parser` package first; add `BlackboxAnalysis` only when derived analysis output is in scope.
- `AirframeCaptions`: shared presentation-string package for App and CLI. It owns every user-facing string through typed accessors backed by Xcode string catalogs (`.xcstrings`). It may depend on `BlackboxReader` and `BlackboxAnalysis` for stable semantic IDs, events, issues, and derived-series kinds. It must not depend on app targets. Domain packages must not depend on `AirframeCaptions`; App/CLI materialize captions at the output boundary.
- `Logging`: local infrastructure Swift package copied into `Airframe/Packages/Logging`. It exposes a dependency-free `Logging` target for `os.Logger` plus an in-memory session buffer. It intentionally has no `ErrorReporting` target and no third-party dependencies.
- `AirframeUI`: optional future SwiftUI components for reusable, data-driven graph/status widgets such as graph panels, seek bars, legends, field values, configuration, and controls. App-specific screens and navigation containers stay in the app target. Current code also uses this package for app-facing document/opening state models. Depends on `BlackboxCore`, `BlackboxReader`, and `Logging`; add `BlackboxAnalysis` only when reusable analysis-backed widgets need it.
- `AirframeApp`: optional future iOS/macOS Universal app shell, file import, document handling, persistence, video integration, and platform-specific capabilities.
- Current app shell structure:
  - `Airframe/App/Airframe.xcodeproj` is the native Universal SwiftUI app project.
  - App target/product/display name is `Airframe`.
  - Bundle ID is `com.kumkju.airframe`.
  - App Store listing name is `Airframe Blackbox Analyzer`.
  - The project references `Airframe/Packages` from the app project as `../Packages` and uses package products visible from that referenced folder for app linkage.
  - Existing packages are not duplicated as hand-made Xcode library targets.
  - `AirframeCLI` remains SwiftPM-only for product purposes and is not linked into the app.
  - App accent color is `#d3fc03`.
  - Document ownership is native at the platform boundary: `AirframeNSDocument` creates macOS document windows, while `AirframeUIDocument` retains iOS security-scoped URLs inside the existing single-window `HomeView`.
  - `AirframeWorkspaceController` is the shared `@MainActor` observable owner. Package-internal mutations advance a revision and use one debounced, serialized silent-save handler; they never drive the native edited/change-count state. Raw Betaflight workspaces do not install package persistence.
- `AirframeUI`: Swift package for reusable, data-driven SwiftUI widgets and app-facing document metadata/opening models. App target files own scenes, document registration, document navigation, and platform-specific composition.
- Logging category ownership: each package that logs defines a package-local `PackageLog` namespace using `Log.shared.makeCategory(...)`. Current category names are `blackbox.reader`, `blackbox.stream`, `blackbox.analysis`, `airframe.documents`, and `airframe.cli`.
- Xcode project hygiene: the visible package source folder must be named `Packages`, point to `../Packages`, and must not be copied under `Airframe/App/`. Remove stale duplicate synchronized folder references such as `Packages 2`.

Keep `BlackboxCore` free of SwiftUI, UIKit, AppKit, AVFoundation, MapKit, and persistence frameworks where possible.

Do not add external package dependencies without the user's explicit approval. Prefer standard library, Foundation, Apple platform frameworks, and small in-house code until an external dependency is justified and approved.

## User-Facing Strings And Localization

- `AirframeCaptions` is the only approved source of user-facing strings.
- All app targets, CLI targets, Swift packages, tests, previews, and future packages must consume user-facing text through `AirframeCaptions`.
- No package or target may define its own labels, titles, captions, event names, issue text, header labels, button text, menu labels, placeholders, empty-state text, or accessibility text.
- Allowed exceptions are raw log data, file names, numeric values, debug-only test names, internal IDs, and machine-readable CLI JSON keys.
- `BlackboxCore`, `BlackboxReader`, and `BlackboxAnalysis` expose stable semantic IDs, machine-readable keys, units, precision, typed values, and grouping. They do not own final human-facing text.
- Series values flow from Reader raw fields through `ReaderSeriesPresentation.displayValue(for:context:)`; `BlackboxAnalysisWorkspace` retains one immutable `ReaderSeriesDisplayContext`, and App/CLI obtain localized labels from `AirframeCaptions` at their output boundary. The display context may use validated header calibration and firmware revision data; unavailable calibration falls back to raw values without a guessed unit.
- `BlackboxAnalysis` does not import `AirframeCaptions`; derived series are identified by `AnalysisDerivedSeriesKind` and rendered through `AirframeCaptions` only in consumers.
- Localization must use Xcode-native `.xcstrings` resources processed by SwiftPM or the app target. Do not implement a long-term ad-hoc localization dictionary.

## Development Sequence

- Create a new project directory for Airframe.
- Start with a package-only Swift core.
- Current implementation uses `Airframe/` as the project directory.
- Implemented packages:
  - `Airframe/Packages/BlackboxCore`
  - `Airframe/Packages/BlackboxReader`
  - `Airframe/Packages/BlackboxAnalysis`
- Implemented CLI package:
  - `Airframe/Packages/AirframeCLI`
- Implemented infrastructure package:
  - `Airframe/Packages/Logging`
- The `Logging` package product is linked into the `Airframe` app target for local app logging and proper Xcode package recognition.
- Ignore Xcode app targets and UI work until the model, parser, and analysis packages are proven.
- Implement one aspect/package at a time.
- Require extensive tests for each package before layering more functionality on top.
- Revisit app architecture only after package-level parsing, indexing, and analysis APIs are stable.
- Consider an efficient internal or persisted representation after reading logs if it improves query performance, memory behavior, or app startup. Keep the raw log model and transformed model boundaries explicit.

## Package Separation Candidates

Potential package boundaries to evaluate before implementation:

- `BlackboxCore`: byte stream primitives, encodings, predictors, frame definitions, headers, and one-frame payload decoding.
- `BlackboxReader`: source/file opening, source/log IDs, import sets, compatibility gating, frame streams, events, GPS home state, main-frame history, and recovery.
- `BlackboxModel`: higher-level domain model types for flights, field access, metadata, computed ranges, and queryable sessions.
- `BlackboxIndex`: intraframe directories, chunk indexing, seeking, and time-range queries.
- `BlackboxAnalysis`: app-facing raw/derived series facade, computed fields, smoothing, attitude estimation, FFT/spectrum, and derived signals.
- `BlackboxFixtures`: test fixtures and golden-output helpers, if useful and kept test-only.

Avoid premature package fragmentation. Split only where the dependency direction is clean and tests benefit from isolation.

Resolved package boundary:

- `BlackboxReader` is separate from `BlackboxCore`.
- `BlackboxCore` must not grow file loading, import/session assembly, full frame-stream iteration, or recovery loops.
- `BlackboxReader` owns the lazy decoded-log API through `DecodedLog`, `ReaderLogSchema`, `ReaderFrameSchema`, `ReaderField`, and `NamedReaderFrame`.
- `BlackboxReader` owns memory-light summaries through `DecodedLogSummary`, `ReaderEventSummary`, `DecodedLogSummaryResult`, `DecodedLog.summarize()`, and `BlackboxReader.summaries(in:)`.
- `BlackboxReader` owns fast header-only metadata through `ReaderHeaderPreviewOptions`, `ReaderHeaderPreview`, `DecodedLogHeaderInfo`, `DecodedLog.headerInfo`, `BlackboxReader.headerInfos(in:)`, and `BlackboxReader.previewHeaders(fileAt:options:)`.
- `BlackboxReader` owns header-name semantics through `ReaderHeaderKey`, `ReaderHeaderDefinition`, `ReaderHeaderValueKind`, `ReaderHeaderSemanticKey`, `ReaderHeaderSemanticValue`, `DecodedLogHeaderInfo` lookup helpers, and `DecodedLogFlightInfo.infoReport(showEmpty:)`. CLI/app consumers should use semantic values and report rows instead of raw header names. `BlackboxCore` remains limited to raw header lines, frame definitions, and compatibility primitives.
- `BlackboxReader` owns scan-backed general flight information through `DecodedLogFlightInfo`, `DecodedLogFlightInfoResult`, `DecodedLog.flightInfo(using:progressHandler:)`, and `BlackboxReader.flightInfos(in:)`.
- `BlackboxReader` owns the first syncpoint index through `ReaderLogIndex`, `ReaderSyncPoint`, and `DecodedLog.makeIndex()`.
- `BlackboxReader` owns combined per-log metadata/index scanning through `DecodedLogScan`, `DecodedLogScanProgress`, and `DecodedLog.scan(progressHandler:)`. The scan is the single decode pass for whole-flight data: `DecodedLogScan.overview` (`ReaderScanOverview` with `ReaderScanSample`s carrying the full main-frame field layout, adaptive stride decimation budgeted by `Configuration.maxScanOverviewSampleCount`, plus complete `ReaderEventRecord`s with truncation flag) feeds every overview-level consumer without further decoding. `BlackboxAnalysis` projects overview samples into chart points through `BlackboxAnalysisWorkspace.overviewPoints(for:in:)` (`AnalysisOverviewPoint`, `AnalysisOverviewProjectionError`); new series kinds extend this projection, never the decode. `summarize()`/`makeIndex()` skip overview collection.
- `BlackboxReader` owns partial main-frame range decoding through `ReaderMainFrameRange` and `DecodedLog.mainFrames(fromMainFrameTime:throughMainFrameTime:using:)`.
- `BlackboxReader` owns all-frame random access through `ReaderFrameRange` and `DecodedLog.allFrames(fromMainFrameTime:throughMainFrameTime:using:)`.
- `BlackboxReader` owns selected main-frame field ranges through `ReaderFieldSelector`, `ReaderFieldSample`, `ReaderFieldRange`, and `DecodedLog.mainFrameFields(...)`.
- `BlackboxReader` owns consumer-ready series access through `ReaderSeriesCatalog`, `ReaderSeriesTable`, `ReaderViewportResult`, `ReaderSeriesCSV`, and `ReaderSeriesRequest`. Series APIs use explicit `ReaderSeriesID` identity with marker, field name, and field index; CSV remains a leaf encoder over typed series table data.
- `BlackboxReader` owns raw series presentation metadata through `ReaderSeriesPresentation`, `ReaderSeriesUnit`, `ReaderSeriesPresentationGroup`, `ReaderSeriesAxisHint`, and `ReaderSeriesValueScale`. This layer describes decoded Reader series for consumers; it is not a graph configuration system, not an upstream presentation port, not a chart API, and not an analysis layer.
- `BlackboxReader` owns conservative raw display values through `ReaderSeriesDisplayValue`, `ReaderSeriesDisplayContext`, and `ReaderSeriesPresentation.displayValue(for:context:)`. Reader display values preserve raw values and only scale safe, stateless cases such as time seconds and GPS coordinate degrees.
- `BlackboxAnalysis` depends on `BlackboxReader` and owns the app-facing series facade through `BlackboxAnalysisWorkspace`, `AnalysisSeriesCatalog`, `AnalysisSeriesTable`, and `AnalysisViewportResult`. App chart, inspector, and field-picker surfaces should usually consume Analysis instead of stitching Reader and derived values together themselves.
- `BlackboxAnalysis` wraps raw Reader series, applies Reader display values for app-facing numeric output, and computes derived series. The first implemented derived series are motor min/max/average, PID sum per qualifying axis, and debug raw descriptors with debug-mode label context. GPS local coordinates/distance/azimuth and attitude estimates are represented in type space but stay catalog-gated until prerequisites are reliable.
- `BlackboxReader` may use Foundation for `Data` and `URL` loading, but stays free of SwiftUI/UIKit/AppKit.
- `BlackboxReader` currently keeps source bytes in `SourceFile` for simple repeatable stream construction. Revisit this after performance profiling with larger logs.
- Decoding is lazy and sequential within one `FrameStream`; coarse parallelism should happen across independent files/logs first. Current random-access support indexes valid `I` frame syncpoints by main-frame time and can resume either valid main-frame-only output or broader all-frame output from a syncpoint state.
- `BlackboxReader.previewHeaders(fileAt:options:)` reads bounded file prefixes and returns raw headers, common metadata, Explorer-style header groups, frame-definition names, and preserved unknown fields without opening full import sets or decoding frames.
- `DecodedLog.flightInfo(using:progressHandler:)` combines header metadata and `DecodedLogScan` for richer flight information such as duration, sample rates, frame counts, syncpoint count, and issues. This path may scan and is not the QuickLook path. When no prebuilt scan is supplied, it can emit one `DecodedLogScanProgress` update per decoded frame, with byte-range fraction and decoded frame count.
- `DecodedLog.mainFrameFields(...)` reuses `mainFrames(...)` and existing syncpoint indexes to produce compact selected `I`/`P` field samples over main-frame time ranges.
- `DecodedLog.seriesCatalog` is schema-only and performs no scan, frame decoding, or file I/O. `ReaderSeriesCatalog.presentation(for:)`, `ReaderSeriesCatalog.presentedDescriptors(for:)`, and `ReaderSeriesDescriptor.presentation` provide schema/ID-only default metadata without consuming streams. `DecodedLog.mainFrameSeriesTable(...)` validates unique, supported, main-frame-queryable series and projects existing `ReaderFieldRange` output into typed rows with explicit missing cells. `DecodedLog.frameSeriesTable(...)` validates unique, supported numeric `I/P/S/G/H` selectors and projects `allFrames(...)` output into typed rows with context main-frame time, marker, byte range, ordinal, and explicit missing cells. `DecodedLog.viewportSeries(...)` returns raw chart-ready exact or min/max-bucketed points. `DecodedLog.seriesCSV(...)` and `DecodedLog.frameSeriesCSV(from:)` encode selected raw series tables without writing files.
- `BlackboxAnalysisWorkspace.seriesCatalog` exposes one app-facing catalog over logical main-frame series. `seriesTable(...)` and `viewportSeries(...)` call Reader range APIs internally, preserve Reader issues, and return `Double` values that may be raw, display-scaled, or derived depending on the selected series.
- `DecodedLog.summarize()` iterates one log once without storing every frame. `DecodedLog.scan(progressHandler:)` collects summary and syncpoint index in one pass for callers that need both and can report frame-level byte progress. `BlackboxReader.summaries(in:)` uses structured concurrency to summarize independent logs in parallel on platforms where task groups are available.
- Security boundary:
  - `BlackboxCore` remains IO-free and exposes checked integer helpers plus bounded scanner/interpreter entry points for untrusted bytes.
  - `BlackboxReader.Configuration` is the central budget surface for file/import size, source/log counts, header limits, frame field count, event string length, retained issues, syncpoints, range frames, field samples, selectors, CSV output, header preview, and async log-task batching.
  - Reader APIs that materialize untrusted-file-derived output must enforce these budgets before app/UI integration.
  - Corrupt input should surface as typed errors or `ReaderIssue`s, never assertions or forced unwraps.
  - Total issue counts may exceed retained issue arrays; retained arrays can include an explicit truncation marker.

## Swift Conventions

- Use Swift 5.9 as the language version. Do not move to Swift 6 language mode without explicit user approval.
- Build targets may use the latest stable iOS and macOS releases.
- Prefer modern Swift domain modeling, including enums with associated values where they express valid states better than loose structs or flags.
- Prefer value types for parsed data and analysis results where practical.
- Prefer async/await and structured concurrency over completion blocks.
- Avoid blanket `@MainActor`; core packages should remain UI-independent and generally non-main-actor-bound.
- Prefer one-line calls and function declarations when they fit within 150 characters.
- Prefer namespacing with nested types where it improves clarity. Example: if there is a `Parser`, its parse result should be `Parser.Result`.
- Put each large type in its own file.
- Small subordinate types used primarily by one parent type may live in the same file as extensions if they remain compact and local.
- If a subordinate type is used by many other types, give it its own file.
- Prefer `throws` over returning Swift `Result` values.
- When a type has domain-specific failures, attach a nested or extension-defined `Error` type with concrete cases for that type.

## Testing Conventions

- Use modern Swift Testing for package tests.
- Use `#expect` for normal assertions and `#require` for prerequisites that subsequent test lines depend on.
- Prefer parameterized tests for parser fixtures and encoding/decoding cases.
- Keep tests parallel-safe by default; fix shared state rather than serializing tests unless serialization has a clear rationale.
- Use XCTest only for capabilities Swift Testing does not cover, such as UI automation or Xcode-specific performance metrics.

## Versioning

- Use Semantic Versioning.
- All Swift Packages and every Xcode target must always share the same version number.
- Keep the shared app/target version in xcconfig files.
- `Base.xcconfig` must define `MARKETING_VERSION`.
- Other xcconfig files may include `Base.xcconfig` to inherit the shared version.
- Avoid per-target version drift in project files or package metadata.

## Core Concepts To Model

- Imported log set containing one or more raw log files.
- Raw log file with one or more Blackbox logs/flight sessions.
- Flight/session identity that remains distinct from both the source file and parsed frame stream.
- Header and firmware metadata.
- Frame definitions for each frame type.
- Field definitions: name, predictor, encoding, signedness, units or presentation metadata.
- Parser events for main, slow, GPS, GPS home, and event frames.
- Intraframe directory/index for efficient seeking.
- Time-based chunk access.
- Computed fields such as attitude, PID sum/error, scaled RC command, GPS cartesian coordinates, distance, azimuth, and trajectory tilt.
- Error and corruption reporting that can preserve partial usability.

## Multi-File And Multi-Flight Requirement

Airframe should eventually support importing several log files in one action and showing the contained flights/sessions separately. The core data model should preserve these boundaries:

- `LogImport` or equivalent: a user import operation containing one or more source files.
- `LogFile` or equivalent: one physical `.bbl`, `.bfl`, `.txt`, `.log`, or unknown file.
- `FlightLog` or equivalent: one parsed Blackbox log/flight session inside a source file.
- `FrameStream` or equivalent: decoded frames for one flight/session.
- Current concrete Reader types:
  - `ImportSet`
  - `SourceFile`
  - `Log`
  - `SourceID`
  - `LogID`
  - `FrameStream`
  - `DecodedLog`
  - `ReaderLogSchema`
  - `NamedReaderFrame`
  - `DecodedLogSummary`
  - `ReaderFrame`
  - `ReaderEvent`
  - `ReaderIssue`

This requirement is deferred from the first implementation step, but parser and indexing APIs should avoid assuming a single file always maps to a single flight.

## Native App Document Model

The native app is read-only and document-based.

- Register `.bbl` and `.bfl` only.
- Do not register `.txt` or `.log`.
- Use `NSDocumentController` plus registered `AirframeNSDocument` on macOS and `AirframeUIDocument` inside the iOS `HomeView`.
- Use `LogDocument` in the app target for file type handling and read-only document behavior.
- Use `AirframeDocumentModel` in `AirframeUI` for source name, byte count, log summaries, and Reader issues.
- Preserve source file, log segment, and session identity; do not collapse them into one flat log.
- Original log files must not be modified by the app.
- Later optional import of `.txt` or `.log` files must be explicit and content-sniffed, not system-wide file association.
- The Settings-only SwiftUI scene does not synthesize document File commands. `DocumentFileMenuPolicy` installs Open/Open Recent/Open Folder/Close/Save/Duplicate/Rename/Move/Revert as native AppKit menu items, with `Open Folder…` directly below `Open Recent` and above the first divider. The responder chain selects the active document and performs normal validation for document commands. Native Save As is intentionally absent; physical `Duplicate…` and `Move To…` cover copy and relocation without rebuilding packages. Raw-log write-family validation lives in `AirframeNSDocument.validateUserInterfaceItem`; menu actions are never cleared permanently. Do not replace SwiftUI `.newItem`/`.saveItem` command groups.
- Airframe package duplication is a coordinated filesystem operation, not an `NSDocument` in-memory duplicate: flush, user-selected destination, byte-preserving package-directory copy, format validation, then native open. This preserves unknown future entries and avoids an untitled duplicate whose silent persistence has no URL.
- The Navigation menu uses SwiftUI's default `CommandMenu` position (between View and Window).
- `DocumentHomeView.LogViewCommandState` is Equatable over a `Capabilities` value only (closures live in a non-compared `Actions` payload); the no-context detail branch publishes `LogViewCommandState.unavailable` so command menus keep a stable structure during document loading and only flip enablement once at load completion. Keep new command state additions inside `Capabilities` (semantic, Equatable) or `Actions` (closures) accordingly.

## Native Log Data Views

- `DocumentHomeView` owns the document split structure.
- The sidebar is contextual navigation only: file identity, basic file facts, and log selection.
- The main detail area owns the selected log's data views.
- The user-facing term is `View`; current view choices are `Overview`, `Table`, `Graph`, and `Spectrum`.
- Put each view family under `Airframe/App/Airframe/App/DocumentHome/Content/<View>/`.
- Keep view-family namespaces nested under `DocumentHomeView`, for example `DocumentHomeView.Table.Container`.
- Xcode target Swift filenames must still be unique across folders; use names like `TableContainer.swift` and `GraphInspector.swift`, not repeated `Container.swift` or `Inspector.swift`.
- Pass the selected log to subviews through `EnvironmentValues.airframeLogContext`.
- `DocumentHomeView.LogContext` can bridge `AirframeLogSummary`, optional `DecodedLog`, `BlackboxAnalysisWorkspace`, retained issues, and progress into reusable view code.
- macOS uses a top-toolbar segmented picker plus `Command-1` through `Command-4` menu commands for view selection.
- Per-window UI state (view selection, macOS inspector visibility, sidebar column visibility) lives in `DocumentStateStore` (`@Observable`, one instance per document window created in `DocumentView`, injected via `EnvironmentValues.documentStateStore`). It reads once at init — the document's rolling-buffer entry supersedes the global UserDefaults keys — and `persist()` writes back on window close, app termination (macOS), and scene backgrounding (iOS), but only when values changed against the loaded baseline; then to both globals and the document entry.
- `DocumentStateRepository` owns the per-document rolling buffer (`airframe.documentStates`, cap 50, LRU by `updatedAt`, raw strings only) keyed by `LogDocument.contentIdentity` (`v1:` SHA-256 fingerprint over length + first/last 64 KiB). It is the single seam for the planned iCloud key-value-store mirror.
- `DocumentStateRepository` mirrors that buffer only through `NSUbiquitousKeyValueStore` under `airframe.documentStates.v1`. It merges local/remote entries per identity by `updatedAt` (remote wins ties), applies the existing cap, and retains UserDefaults-only operation when iCloud is unavailable. Remote changes never mutate existing `DocumentStateStore` instances; only future windows read merged state. Global fallback keys remain local to each device.
- macOS signing uses a platform-specific entitlement file with App Sandbox and read-only user-selected-file access. The shared entitlement file enables iCloud Key-Value Storage. No URL/bookmark persistence exists because documents are not reopened automatically.
- macOS document windows are not restored across quit/login. `AirframeAppDelegate` opens the standard document Open panel when the user reopens an already-running, window-free app; otherwise it leaves the app window-free after the last document closes.
- `Table`, `Graph`, and `Spectrum` use SwiftUI's native `.inspector(isPresented:)` on all platforms; `Overview` has no inspector.
- Inspector width uses `.inspectorColumnWidth(min: 300, ideal: 320, max: 460)`; the system persists resizes. The presented state is one shared value for all view modes; macOS persists it (`airframe.logView.inspectorPresented`), iOS/iPadOS uses a session-scoped toggle that starts closed and closes on view switch. `Overview` hides the inspector without changing the stored value.
- Do not use AppKit-backed `VSplitView`/`HSplitView` inside the `NavigationSplitView` detail column and do not give the detail content hard minimum widths; both can make the macOS sidebar overlay the content instead of pushing it.
- macOS document windows use 1180x660 minimum and 1280x760 default with a 300-point sidebar minimum. The main content may compress when sidebar and inspector are open.
- `Table` and `Graph` show the shared `DocumentHomeView.LogTimeline` below a `Divider` (fixed `LogTimeline.height`); conceptually one timeline with one state across both views. The timeline is implemented: motor-average-percent `AreaGraph`, event marker lines, and a draggable current-position line backed by `DocumentStateStore.logPositions` (main-frame µs per segment index). `LogTimeline.ModelStore` (environment `\.logTimelineModelStore`, one per document window) caches computed `LogTimeline.Model`s.
- `AirframeUI` owns reusable graph rendering: `GraphSample`, `GraphDomain`, `GraphProjection`, `AreaGraph`, and the style types `AreaGraphStyle`, `GraphLineStyle`, `GraphGridStyle`. Graph views are data-driven and theme-free; callers provide all colors and layer overlays/gestures on top using the shared public `GraphProjection` mapping.
- `BlackboxAnalysis` owns motor normalization through `AnalysisMotorOutputRange` and the derived `motorAveragePercent` series; `AnalysisSeriesID.derived(_:)`/`.reader(_:)` are public factory helpers for consumers.
- `BlackboxAnalysis` owns attitude estimation through `BlackboxAnalysis/Attitude/`: `AnalysisAttitudeEstimator` (pure complementary filter tracking a gravity direction and a heading reference in the body frame; both rotated by integrated gyro deltas each frame; gravity blended toward the accelerometer with a sample-rate-independent time-constant weight when the reading magnitude is inside a 0.85...1.15 g band; 0.25 s time constant; level reset on frame gaps over 0.5 s; `roll = atan2(gravityY, gravityZ)`, `pitch = atan2(-gravityX, hypot(gravityY, gravityZ))`, yaw from the heading reference and drift-prone). The accelerometer is consumed in the recorded flight-controller convention where it points along the gravity reference at rest (`accSmooth[2]` positive), so no axis negation happens at the boundary. `AnalysisAttitudeTimeline`/`AnalysisAttitudeSample` (decimated to >= 10 ms cadence, `sample(at:)` binary search last-at-or-before), and `BlackboxAnalysisWorkspace.attitudeTimeline(fromMainFrameTime:throughMainFrameTime:using:cancellationToken:)` which windows the full-rate decode in 25 s slices, converts gyro via display scaling (deg/s) times pi/180, and falls back to gyro-only with `accelerometerUsed = false` when `accSmooth`/`accADC` or `acc_1G` are missing. Typed failures via `AnalysisAttitudeError` (`missingGyroFields(available:)`, `missingGyroScale`, `invalidTimeRange`, `cancelled`). Attitude is a dedicated API like Step Response, not a graphable derived series; the `AnalysisDerivedSeriesKind.attitude*` cases remain catalog-gated stubs. `motorPercent(forRawValue:)` and `motorSeriesFieldNames` are the public motor-normalization seam for the app.
- `AirframeUI` owns the craft visualization through `AirframeUI/Craft/`: `CraftRenderModel` (roll/pitch radians, `attitudeAvailable`, four `Motor` percent/color entries in Betaflight quad-X order 0 rear-right, 1 front-right, 2 rear-left, 3 front-left), `CraftSilhouetteShape`, and `CraftSurfaceCanvas` with injectable `Style`. Pseudo-3D Canvas projection with a fixed viewer-tilt coefficient so roll/pitch direction is visible in a top-down orthographic view; rotor ring gauges fill clockwise from 12 o'clock.
- The app's Graph inspector hosts `DocumentHomeView.Graph.CraftSection` (`Graph/GraphCraftSection.swift`) as the first Form section: collapsible via `@AppStorage("airframe.graph.craftSectionExpanded")` (default expanded), quad-only gate on exactly 4 motor fields, cursor-driven motor gauge readout (raw `mainFrameFields` +-50 ms window, `motorPercent(forRawValue:)`), per-log attitude timeline cached in view state including real failures (never `.cancelled`), zero data work while collapsed with in-flight cancellation, motor colors from the first graph section containing the motor series (palette slot) with motor-index fallback.
- `BlackboxAnalysis` owns automatic timeline range detection through `BlackboxAnalysisWorkspace.automaticTimelineRange(using:)`. The app supplies the already-opened `DecodedLogFlightInfo`; Analysis performs one exact indexed full-log query for `motorAveragePercent`, derives an idle-relative sustained start threshold from exact samples, validates log identity and duration rules, and returns either `AnalysisAutomaticTimelineRange` or `nil`. Reader/query failures propagate as thrown errors for app logging.
- `LogContext` additionally carries `flightInfo: DecodedLogFlightInfo?` retained by `AirframeDocumentOpenModel` during loading, so consumers reuse the scan-backed syncpoint index instead of rescanning.
- `ReaderScanOverview` carries `lastTerminationEventContextMainFrameTime` as a separate unbounded-by-marker-list fact. The scan overview still keeps bounded event records for UI markers, but final disarm/log-end context must survive event floods for automatic range detection.
- `DocumentStateStore` owns the atomic automatic-range write seam: `hasStoredTimelineRange(forSegmentIndex:)` distinguishes an actual persisted `logRanges` entry from the implicit full-log fallback, and `setAutomaticTimelineRange(_:forSegmentIndex:defaultRange:replacingExisting:)` refuses overwrites for automatic open/reset paths while allowing the user-initiated Timeline `Auto` button to replace an existing stored range.
- macOS window toolbar: previous/next log arrows next to the file proxy (`ToolbarItemGroup(placement: .navigation)` in `DocumentHomeView`) step through the document's logs.
- During log scanning, the selected view should show the existing centered progress view instead of placeholder content.

## Native Settings

- App-global settings live in `AirframeGlobalSettings`, backed by local `UserDefaults` plus `NSUbiquitousKeyValueStore` through the existing cloud-store seam. Cloud values win over local values at initialization; external KVS changes update observed properties and mirror locally through the same persistence path.
- `SettingsView` is app-target SwiftUI. macOS uses a native `Settings` scene and a `TabView` with the visible `General` tab. iOS/iPadOS use a Home toolbar gear and a sheet containing `NavigationStack { SettingsView() }`; the iOS view is a `Form` with a `General` section rather than a one-item tab bar.
- Settings labels, titles, and explanations are typed `AirframeCaptions` values. Do not add app-target user-facing literals for settings UI.

## SwiftUI Preview Convention

Every SwiftUI view file in the app target and in `AirframeUI` must have at least one preview block inside `#if DEBUG`.

- Treat the file as the coverage unit. A file with several private helper views can use one top-level preview block that exercises those helpers through realistic states.
- Use real production display/model/state types in previews.
- Add debug-only `makeDebug...` factories to real model/state types when preview setup would otherwise be noisy.
- Wrap views in realistic context, such as `NavigationStack`, `NavigationSplitView`, or small preview containers, when the view depends on surrounding UI.
- Keep preview injection minimal and preferably debug-only.

## MVP Scope Proposal

The smallest useful native proof of concept should demonstrate:

1. Open one or more `.bbl`, `.bfl`, `.txt`, `.log`, or unknown small log files through system file import.
2. Parse headers and list contained files and flight sessions separately.
3. Open one flight/session and expose min/max time, firmware, craft name, looptime, and sample rate.
4. Query frames by time range within a selected flight/session.
5. Render a native SwiftUI/Canvas or Metal-backed chart for a few fields:
   - `gyroADC[0..2]`
   - `rcCommand[0..3]` or setpoint equivalent
   - `motor[0..n]`
6. Scrub through time with a seek bar.
7. Export parsed data to CSV.

Defer these until the core is proven:

- Video sync.
- Video export.
- Full graph configuration/workspaces.
- Spectrum analyzer.
- Map view.
- 3D craft view.
- Direct flight controller access.

## Parser Implementation Strategy

Recommended approach:

- Build an independent Swift parser in small vertical slices.
- Use upstream sources sparingly as references for format behavior and compatibility edge cases, not as source text to translate or as the next validation oracle.
- Start with Swift-native byte stream and primitive decoder APIs.
- Add header parsing with project-owned types and names.
- Add frame definitions as Swift domain models rather than copies of upstream structures.
- Add one frame type at a time, driven by tests and observed behavior.
- Build fixtures and golden outputs early.
- Prefer internal Swift fixtures, snapshots, and local smoke logs for the next slices. External oracle validation is deferred.

Avoid designing the UI before `BlackboxCore` can parse real logs reliably.

## Graph Setup State

`GraphSetup` is app-owned per-document state. It has one fixed Table section (`Table Columns`) and ordered editable Graph sections. Sections persist only a name and ordered `AnalysisSeriesID.rawValue` values in a compact versioned property-list payload; unknown IDs remain retained. Table and Graph assignments are independent. Future graph rendering consumes graph sections as equal-height, shared-time-domain panels with independent Y domains.

## Testing Strategy

The upstream project does not appear to have strong parser test coverage. A Swift implementation should compensate with:

- Golden fixture logs.
- Reader frame-stream snapshots for stable package-local fixtures.
- At least one single-flight fixture, one multi-flight-in-one-file fixture, and one multi-file import fixture set.
- Header parsing snapshots.
- Decoded frame snapshots for known logs.
- CSV comparison against `blackbox_decode` from `blackbox-tools` only in a later validation phase.
- Fuzz-ish corruption tests for truncated frames and invalid encodings.
- Performance tests for large logs and random seeking.
