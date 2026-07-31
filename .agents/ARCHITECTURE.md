# Current Architecture

## Airframe document storage

- Normal `.airframe` documents are regular files backed by `AirframeContainer`; the application does not reconstruct or persist directory packages in ordinary open, save, duplicate, raw-log, or flight-controller flows.
- Temporary legacy support is one-way and isolated in `WorkspaceDocument/Container/LegacyAirframeConverter.swift`. It preflights the selected package before presenting the destination dialog and publishes a fully validated regular container.
- `AirframeContainerTransfer` prebuilds and validates regular files for SwiftUI export so platform document pickers never define the physical document format through a `FileWrapper` directory.
- `LegacyFormatIsolationGuardTests` statically confines legacy directory symbols to the converter and dedicated legacy tests.
- `DOCUMENT_IO_MATRIX.md` defines every user-visible URL boundary and its automated/manual verification status. `AirframeSavePanel` owns native save type/extension policy; candidate writers publish only to the exact selected URL through coordinated replacement.

This file describes the current technical shape. Stable product and workflow rules live in `MEMORY.md`; future ideas live in `BACKLOG.md`.

## AirframeContainer

- `Packages/AirframeContainer` depends only on local `Logging` and supports iOS and macOS.
- The file has a fixed 4 KiB header, two CRC-protected locator slots, aligned immutable blobs, complete snapshot commits, and a footer.
- Locator publication after synchronized blob and commit writes is the durable boundary. Readers choose the newest valid commit and support bounded recovery.
- Stable physical blob handles drive retention and logical deletion; commit-local identifiers may change.
- Reader APIs provide bounded reads, range reads, and streaming copy without loading large blobs on open.
- Full compaction streams live blobs into a validated sibling candidate. Tail compaction uses APFS clone-and-truncate with streaming fallback.
- The app-owned manifest maps normalized logical paths to kind, byte count, and SHA-256 without persisting offsets or handles. Logical metadata remains schema v2.
- `AirframeDocumentStore` serializes revisions outside the Main Actor while AppKit/UIKit objects retain lifecycle and security-scope ownership.

## Overview Dashboard

- The Overview composes reusable technical cards in an adaptive `LazyVGrid`; Notes is outside the grid and spans the available width.
- Card-level details remain auxiliary sheets, while the GPS flight map is a primary `LogViewSelection` mode.
- The requested data-card order is Log, Flight, GPS, Power, Flight Controller, Hardware, Blackbox, Configuration, then Notes; the existing Checks card follows Configuration without interrupting that data sequence. GPS uses the existing cached `AirframeFlightOverview` fields; no cache schema change is required.
- Semantic Overview snapshots are cacheable package data. Cache identity includes the immutable source SHA-256, segment index, schema version, calculation algorithm version, and configuration input identity.
- Blackbox availability comes from parsed frame definitions, never merely from configuration intent. Compact category summaries lead to a searchable detail that retains raw unknown fields.
- Flight GPS overview data includes GPS-home epoch date/time when the `H` frame provides it, falling back to a valid `Log start datetime` header. `GPS_time` is only GPS milliseconds-of-week and is not enough for a calendar date. The same overview also includes maximum displacement and total travelled distance from valid GPS coordinates.

## GPS Route and Map

- `BlackboxReader` retains bounded `ReaderScanGPSPoint` values and the first valid `ReaderScanGPSHome` during the existing scan. Adaptive halving preserves the first and final usable route points while aggregate GPS metrics remain full-resolution.
- `BlackboxAnalysisWorkspace.gpsRoute(using:)` builds an immutable MapKit-free `AnalysisGPSRoute`, drops non-monotonic points, calculates Home-relative altitude, normalizes heading, associates at most 256 events with preceding route points, and provides binary-search cursor projections.
- The app owns transient MapKit camera state and persisted per-segment map display settings. Route prefixes, position, and Map event annotations read the shared document cursor; profile event lines show the complete prepared event set. Map playback always uses the complete Main-frame range. In the segmented mode picker, menu, and numeric command shortcuts, Map is displayed as the final/rightmost mode and uses `⌘6`.
- `DocumentHomeView.LogContext.hasUsableGPSRoute` is the app-side shared gate for Map segment enablement, command routing, Map fallback, and Overview GPS-card visibility. It requires at least two monotonic time-associated GPS points with distinct coordinates; while scan/loading state is unresolved, Map fallback is deferred.
- The route overlay uses the latest recorded GPS-point index as its SwiftUI identity, prompting immediate MapKit overlay replacement only when a new point is reached while preserving camera state. The current-position annotation keeps stable identity so its dot and heading cone do not blink during Playback.
- Display-only route geometry is capped at 2,048 deterministically sampled points. First/final endpoints, every prepared Event route point, and the live current endpoint are retained; Analysis route data and position/event lookup remain unchanged.
- Map annotations expose localized accessibility labels without visible titles. The current-position cone rotates around an apex fixed at the dot and widens in the recorded heading direction.
- Home and progressively revealed Event symbols are native buttons with anchored transient popovers. Home shows coordinate and recorded absolute altitude; Events show localized title, flight-relative time, coordinate, and available relative altitude. Selection clears when scrubbing or settings hide its annotation.
- `GraphMarkerChip` is the single AirframeUI renderer for Graph marker chips and compact Map Event context. `EventMarkerPresentation` is the shared app projection from `ReaderEvent` to text/state chip content: Flight Mode payloads resolve firmware-version-specific bit changes through the shared mode table, while Inflight Adjustment payloads reuse shared function/scaling captions. Generic Map Events omit the chip to avoid duplicating their popover title.
- The altitude profile aligns its dynamic Y domain to a stable nice interval and labels every horizontal grid line. Its lower domain never drops below zero unless at least one recorded relative-altitude value is negative.

## Flight Controller Runtime Status

- `BetaflightClient.runtimeStatus()` is a non-fatal framed-CLI enrichment step: it requests structured `env`, falls back to `status`, parses immediately into `FlightControllerStatusSnapshot`, discards the raw response, and restores MSP.
- `FlightControllerStatusSnapshot` is shared by the connected-assistant presentation, `FlightControllerImportPayload`, package metadata import records, and associated-log Overview enrichment.
- Direct, Wi-Fi, and Mass Storage imports retain the status captured during the original live connection. Package metadata stores it as an optional field on the same import event as its log hashes and configuration.
- Overview selects the newest exact status-bearing import for a source hash and combines the semantic status hash with configuration identity for cache validity.

## Layers

```text
BlackboxCore
    ↓
BlackboxReader
    ↓
BlackboxAnalysis
    ↓
AirframeCaptions / AirframeUnits / AirframeUI
    ↓
Airframe app and AirframeCLI
```

Flight-controller import is an independent side path:

```text
Serial / CoreBluetooth transport
    ↓
MSP
    ↓
FlightController
    ↓
FlightControllerImportPayload
    ↓
AirframeImportMaterializer
```

- `BlackboxCore`: byte streams, encodings, predictors, frame primitives, and typed parser failures.
- `BlackboxReader`: imports, source/log/session identity, schemas, frame streams, recovery, scan overview, syncpoint index, range queries, raw series, events, and retained issues.
- `BlackboxAnalysis`: derived series and dedicated calculations such as Spectrum, Step Response, attitude, motor normalization, and automatic timeline range.
- `AirframeCaptions`: typed localization over domain semantic IDs.
- `AirframeUnits`: focused locale-aware numeric and unit formatting.
- `AirframeUI`: reusable data-driven rendering and display models without app navigation ownership.
- App target: document lifecycle, state routing, windows, menus, navigation, settings, and composed views.
- `AirframeCLI`: human and machine-readable inspection/export over Reader and Analysis APIs.
- `MSP`: transport-independent MSP v1/v2 encode/decode, request coordination, and CLI framing.
- `FlightController`: Betaflight-specific device discovery, byte transports, handshake, FlashFS/CLI operations, and file-backed import results.

Dependencies point downward. Domain packages never depend on captions, SwiftUI, app state, or the processing activity counter.

## Data Flow

1. Import preserves physical source-file identity.
2. Reader discovers one or more Blackbox log segments per source.
3. One scan produces summary, issues, syncpoints, events, and a bounded overview.
4. Indexed queries decode full-resolution data for requested time ranges.
5. Analysis maps Reader series to display-scaled or derived series.
6. App/UI consumers build bounded render models and cache them per document.

FC acquisition writes downloaded logs and optional CLI configuration to a managed temporary directory. The assistant returns `FlightControllerImportPayload`; `AirframeImportMaterializer` either creates a package or atomically appends the payload without coupling acquisition to document lifecycle. Log payloads are normalized to the Reader-discovered segment end before package storage, trimming FlashFS tail bytes after a valid terminal log-end marker.

The app's neutral flight-controller runtime consumes provider replacement streams. On macOS it merges serial and Bluetooth snapshots; on iOS/iPadOS it consumes Bluetooth only. Provider-qualified assistant IDs map back to exact provider-owned devices, source failures remove only that source's snapshot, and all transports feed the same acquisition pipeline.

Main-frame time is the primary query axis. Valid auxiliary frames are associated with the active main-frame interval.

## Identity

- `SourceID`: physical imported source.
- `LogID`: one Blackbox segment/session inside a source.
- Full SHA-256: package source identity and payload key.
- Ephemeral UUID: runtime document/window identity only.
- Raw document-state identity: versioned content fingerprint; never a persisted source URL.

Do not collapse source, segment, session, and runtime-window identity.

## Documents

### Raw logs

- Read-only `.bbl` and `.bfl`.
- One primary source plus at most eight session-only references.
- UI state persists externally through the bounded document-state repository and iCloud KVS mirror.

### Airframe packages

- `UTType.package` directory with `metadata.json`.
- Ordered equal `logs` descriptors and SHA-256-keyed source payloads normalized to valid log segment boundaries.
- Format version 2 adds ordered flight-controller import snapshots and content-addressed configuration payloads; version 1 remains readable.
- Metadata owns selection, per-source state, names, and other package UI state.
- Mutations create coalesced snapshots and explicit silent saves.
- Physical duplicate coordinates, copies, validates, then opens the package.

## App Composition

- iOS: `WindowGroup` → `HomeView` → one `AirframeUIDocument` workspace.
- macOS: `NSDocumentController`/`AirframeNSDocument` plus one start window when no document is visible.
- `FlightControllerImportCompletionCoordinator` keeps assistant acquisition independent from new-document destination, persistence, opening, and post-success temporary cleanup. iOS transfers the payload out of the assistant before presenting `fileExporter`; cancellation restores the same completed assistant state.
- `DefaultFlightControllerImportAssistantRuntime` owns cross-platform discovery aggregation and provider routing. Discovery cancellation preserves the latest route map for selected-device handoff; beginning a new scan replaces it.
- `DocumentHomeView` owns the document `NavigationSplitView`.
- Sidebar chooses a log; detail chooses Overview, Table, Graph, Spectrum, Step Response, or Map.
- On macOS, the document content never sets a navigation or window title. `NSDocument`/AppKit owns the filename title and File Proxy automatically; `LogDataView` sets only the navigation subtitle to the selected log's effective name.
- `EnvironmentValues.airframeLogContext` passes the selected summary, decoded log, analysis workspace, issues, progress, and flight info.
- One document-scoped `ProcessingActivityCounter` wraps all app-side data work.
- One shared timeline position/range drives Table, Graph, playback, and future synchronized media.
- The one-pass Reader overview retains a bounded flight-mode state timeline from slow frames and mode events. Graph resolves the primary Craft-preview mode synchronously at the shared cursor; unavailable or incomplete ranges remain explicitly unknown.

## State

- `DocumentStateStore`: per-window transient state and raw-log restoration.
- `DocumentStateRepository`: bounded content-fingerprint-keyed raw state, mirrored through iCloud KVS.
- Package `metadata.json`: authoritative Airframe document state.
- App-global settings: local defaults plus iCloud KVS through `AirframeGlobalSettings`.
- Raw bytes never receive xattrs or app state.

## Presentation

- `AnalysisSeriesCatalog` is the app-facing series catalog.
- Series IDs remain stable semantic identifiers; Reader IDs may be resolved across schema index differences by marker and unique field name.
- Presentation metadata defines semantic group, localized caption key, physical unit, conversion, precision, axis hint, and raw fallback.
- Graph sections are ordered app-owned state. Table and Graph field assignments are independent.
- Reusable graph surfaces are data-driven and theme-free; callers provide style, overlays, and interaction.

## Concurrency And Caching

- A single frame stream decodes sequentially.
- Independent logs may scan concurrently within configured limits.
- Heavy builders must not inherit SwiftUI `View` main-actor isolation.
- Progress updates are throttled before main-actor publication.
- Whole-flight consumers project from the scan overview.
- Full-resolution views use indexed range queries and bounded document-scoped caches.
- Speculative work yields to visible work and is cancelled when its request becomes stale.
- Memory pressure trims caches by priority while protecting the currently visible model.

## Testing

- Swift Testing for packages; XCTest where platform facilities require it.
- Golden compact fixtures for headers, frame streams, events, range queries, and corruption behavior.
- Representative multi-log, GPS, and damaged/truncated fixtures.
- Parser tests assert deterministic typed failures and configured-budget enforcement.
- App tests cover document/package invariants, state routing, commands, and view-model behavior.
- External oracle comparison is supplementary, not the source of implementation structure.

## Log Health Checks

- `BlackboxAnalysis/Health/` owns plausibility checks beyond `ReaderLogQuality`: `BlackboxAnalysisWorkspace.healthReport(using:)` aggregates typed `AnalysisHealthFinding`s (motorPolesMismatch, motorDesync, logDataGaps, erpmWithoutRPMFilter, batteryChargeLowAtArm) plus first-class skip reasons.
- The motor-poles detector reuses the `.frequencyVsRPM` sample buffer (one decode pass), chunked FFTs, and a robust median-ratio estimator. Precision comes from the RPM-span guard (fixed resonances produce RPM-dependent ratios) and the even-pole snap tolerance (2 %), not from the dispersion gates: on real quads every motor's search window latches onto the strongest ridge, so observation scatter equals the motors' RPM spread (~5 %).
- Reports persist per source segment under `indexes/health-checks/<sha256>/<segment>.json` following the overview-cache envelope pattern (`healthCacheAlgorithmVersion`, bump on threshold changes). Raw logs keep reports in memory on `AirframeWorkspaceController.healthReports`.
- The Overview container runs the checks in a deferred background task (1 s settle, `ProcessingActivityCounter`, utility priority) after cache lookup; the `ChecksCard` in the card grid shows its header spinner while this uncached health task is active. It renders Log Quality plus compact finding rows (severity icon, short value like `12 vs. 14`) with the full explanation as a tooltip via `overviewTooltip`.
