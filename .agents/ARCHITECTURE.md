# Current Architecture

- `CurrentSensorCalibrationAssistantState` is transient app-owned UI state with a pure nested calculator and route-specific steps. `DocumentHomeView.Overview.Container` supplies selected-log consumption, header Scale, and an associated-configuration-only fallback; `CurrentSensorCalibrationAssistantView` presents it through the shared `AssistantShell`, `AssistantHeading`, and `AssistantRow` components also used by FC import. The workflow owns no document data, cache, background work, or persistence.

## Airframe document storage

- Normal `.airframe` documents are regular files backed by `AirframeContainer`; the application does not reconstruct or persist directory packages in ordinary open, save, duplicate, raw-log, or flight-controller flows.
- On iOS/iPadOS, `IOSRecentDocumentStore` owns a device-local, versioned `UserDefaults` envelope containing at most eight independently decodable bookmark records and last-known URLs. `HomeView` records only successfully opened `.airframe`, `.bbl`, and `.bfl` files, resolves bookmarks before reopening, refreshes stale records, and removes an entry after a failed Recent open. `AirframeUIDocument` retains the resolved security scope for the open document lifetime. macOS Recent Documents remains `NSDocumentController`-owned.
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
- Full compaction streams live blobs into a validated candidate inside Foundation's same-volume item-replacement directory, then atomically replaces the exact source URL. Tail compaction uses APFS clone-and-truncate with streaming fallback.
- The app-owned manifest maps normalized logical paths to kind, byte count, and SHA-256 without persisting offsets or handles. Logical metadata remains schema v2.
- `AirframeDocumentStore` serializes revisions outside the Main Actor while AppKit/UIKit objects retain lifecycle and security-scope ownership. Every written commit evaluates a full-liveness compaction plan; the existing 10 MiB and 25% thresholds bound metadata history and deleted payloads without adding unchanged-open or unchanged-close work.
- `AirframeNSDocument` refreshes AppKit's `fileModificationDate` after its custom persistence path writes bytes so the native conflict detector recognizes Airframe's own append commits.
- `AirframeNSDocument` opts out of AppKit autosave and suppresses editor-originated document change-count increments. Native editors retain their local undo behavior, while `AirframeWorkspaceController` remains the sole owner of dirty revisions and `AirframeDocumentPersistence` remains the sole save path.

## Overview Dashboard

- The Overview composes reusable technical cards in an adaptive `LazyVGrid`; Notes is outside the grid and spans the available width.
- Card-level details remain auxiliary sheets, while the GPS flight map is a primary `LogViewSelection` mode.
- Checks leads the adaptive card grid, followed by Log, Blackbox, Aircraft, Hardware, Flight Controller, Configuration, Flight, Power, and GPS. Data-dependent cards may be omitted. Full-width Notes remains outside the grid and is available only for writable Airframe documents.
- Semantic Overview snapshots use a versioned OS derived-data cache for Airframe documents and RAM only for raw logs. Cache identity includes immutable source SHA-256, segment index, schema version, calculation algorithm version, and configuration input identity.
- Blackbox availability comes from parsed frame definitions, never merely from configuration intent. Compact category summaries lead to a searchable detail that retains raw unknown fields.
- The Blackbox Overview device prefers the log header and falls back to the associated parsed configuration's `blackbox_device`; the typed fallback is retained in the versioned Overview snapshot, not document metadata. The card resolves the selected source's persisted `FlightControllerStatusSnapshot` once, then its transient `BlackboxStorageEstimate` matches Flash/SD capacity and projects total recording time from exact bytes via `capacityBytes * segmentDuration / segmentByteCount`. Capacity presentation alone floors to a whole decimal B/KB/MB/GB unit. Overview OS-cache dataset version 2 and legacy overview algorithm 14 invalidate pre-fallback derived snapshots.
- Flight GPS overview data includes GPS-home epoch date/time when the `H` frame provides it, falling back to a valid `Log start datetime` header. `GPS_time` is only GPS milliseconds-of-week and is not enough for a calendar date. The same overview also includes maximum displacement and total travelled distance from valid GPS coordinates.

## GPS Route and Map

- `BlackboxReader` retains bounded `ReaderScanGPSPoint` values and the first valid `ReaderScanGPSHome` during the existing scan. Adaptive halving preserves the first and final usable route points while aggregate GPS metrics remain full-resolution.
- `BlackboxAnalysisWorkspace.gpsRoute(using:)` builds an immutable MapKit-free `AnalysisGPSRoute`, drops non-monotonic points, calculates Home-relative altitude, normalizes heading, associates at most 256 events with preceding route points, and provides binary-search cursor projections.
- The app owns transient MapKit camera state and document-wide map display settings. Route prefixes, position, and Map event annotations read the active log cursor; profile event lines show the complete prepared event set. Map playback always uses the complete Main-frame range. In the segmented mode picker, menu, and numeric command shortcuts, Map is displayed as the final/rightmost mode and uses `⌘6`.
- `DocumentHomeView.LogContext.hasUsableGPSRoute` is the app-side shared gate for Map segment enablement, command routing, Map fallback, and Overview GPS-card visibility. It requires at least two monotonic time-associated GPS points with distinct coordinates; while scan/loading state is unresolved, Map fallback is deferred.
- The SwiftUI `Map` owns the progressive `MapPolyline`, Home/Event annotations, and current-position marker. An earlier isolated playback diagnosis observed route-overlay lag, but after Map Timeline preparation and cursor invalidation were separated, live macOS verification found both the map and route line fully fluid even in Debug. A native `MKMapView` representable is no longer planned; historical evidence remains in [Map and Graph Research](knowledge/MAP_AND_GRAPH_RESEARCH.md#swiftui-map-polyline-playback-limitation).
- Display-only route geometry is capped at 2,048 deterministically sampled points. First/final endpoints, every prepared Event route point, and the live current endpoint are retained; Analysis route data and position/event lookup remain unchanged.
- Map annotations expose localized accessibility labels without visible titles. The current-position cone rotates around an apex fixed at the dot and widens in the recorded heading direction.
- Home and progressively revealed Event symbols are native buttons with anchored transient popovers. Home shows coordinate and recorded absolute altitude; Events show localized title, flight-relative time, coordinate, and available relative altitude. Selection clears when scrubbing or settings hide its annotation.
- `GraphMarkerChip` is the single AirframeUI renderer for Graph marker chips and compact Map Event context. `EventMarkerPresentation` is the shared app projection from `ReaderEvent` to text/state chip content: Flight Mode payloads resolve firmware-version-specific bit changes through the shared mode table, while Inflight Adjustment payloads reuse shared function/scaling captions. Generic Map Events omit the chip to avoid duplicating their popover title.
- The altitude profile aligns its dynamic Y domain to a stable nice interval and labels every horizontal grid line. Its lower domain never drops below zero unless at least one recorded relative-altitude value is negative.

## Flight Controller Runtime Status

- `BetaflightClient.runtimeStatus()` is a non-fatal framed-CLI enrichment step: it requests structured `env`, falls back to `status`, parses immediately into `FlightControllerStatusSnapshot`, discards the raw response, and restores MSP.
- `FlightControllerStatusSnapshot` is shared by the connected-assistant presentation, `FlightControllerImportPayload`, Airframe-document import records, and associated-log Overview enrichment.
- Direct, Wi-Fi, and Mass Storage imports retain the status captured during the original live connection. Document metadata stores it as an optional field on the same import event as its log hashes and configuration.
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

Each production import assistant owns one bounded, in-memory `FlightControllerDiagnosticsRecorder`. The same recorder is injected into discovery, serial/CoreBluetooth transports, MSP coordination, Betaflight operations, and app-side Direct/Wi-Fi/Mass-Storage orchestration. Events contain timestamps, stages, symbolic command/service metadata, counts, capabilities, and privacy-safe error domain/code pairs. Durable peripheral or route identifiers are replaced by salted per-session labels; Blackbox/configuration/protocol payloads, credentials, filesystem paths, raw SSIDs, and durable identifiers never enter the recorder. The user can explicitly export a deterministic plain-text snapshot through the assistant's persistent diagnostics action; dismissing the assistant shuts the recorder down and clears its memory.

CoreBluetooth connects without a service scan filter, discovers services after connection, then resolves the first candidate whose service, write characteristic, notify/indicate characteristic, and characteristic properties form a complete UART profile. Multiple layouts may share one service UUID: `FFE0` accepts both split `FFE1` write / `FFE2` notify and shared bidirectional `FFE1`. Manufacturer and advertised device names do not select the transport profile; the later Betaflight MSP handshake validates controller compatibility.

The first idempotent `MSP_API_VERSION` request has one timeout retry regardless of the default request retry setting. This absorbs the hardware-validated post-notification race on BLE UART bridges without imposing a fixed delay on every connection or changing retry behavior for later identity, configuration, and download requests.

USB configuration capture retains canonical `dump all`. After Bluetooth connects, its resolved GATT characteristic layout reports whether long continuous responses are supported. Every recognized profile uses canonical `dump all` except the hardware-validated shared-`FFE1` `FFE0 UART` layout, which uses Airframe's comprehensive segmented format; unresolved/unknown Bluetooth remains on that conservative fallback. The same capability controls whether CLI `env`/`status` enrichment is attempted. Format 2 is backed by generated upstream setting catalogs for BF 4.3 through 2026.6 plus raw MSP configuration records, emits its setting/profile portion as a safe replayable CLI batch, and ends with `save`. Pre-4.5.4 constrained controllers remain in one interactive CLI session and reconnect after exit/reboot; framed firmware uses bounded commands, while API 1.48+ reads values through `MSP2_CLI_SETTING`. Direct constrained capture runs before the log because it may require a reconnect; Direct complete-dump capture preserves the original proven order after the log transfer. Wi-Fi and Mass Storage expose configuration as a separate initial determinate stage.

Log import provenance belongs to each immutable log descriptor, not only an import event: `file`, `usbCable`, or `bluetooth`. The value records the initial controller-contact path, so Wi-Fi and Mass Storage remain Bluetooth imports even though the log bytes later travel over another channel. Raw files and newly attached file sources are marked as files. Older descriptors tied to an FC import but lacking provenance remain unknown.

Runtime hardware capture follows transport capability rather than guessed firmware/bridge combinations. Every connection first builds a baseline from bounded board/MSP responses; generated upstream hardware catalogs map version-specific active-sensor IDs for API 1.46+, and API 1.47+ supplies the MCU name directly. USB additionally attempts CLI `env` and `status` and merges their richer facts over the baseline. Bluetooth, including the BLE setup leg used by Wi-Fi and Mass Storage, never requests those potentially large continuous responses.

`FlightControllerImportAssistantState` automatically selects a device only when no selection exists. Subsequent discovery snapshots retain the selected ID even while its BLE advertisement is temporarily absent, making `selectedDevice` nil and disabling Next instead of falling back to another transport. The selection becomes usable again if the same ID reappears; an explicit Bluetooth visibility-filter change may clear a now-hidden selection and choose a visible default.

- `BlackboxCore`: byte streams, encodings, predictors, frame primitives, and typed parser failures.
- `BlackboxReader`: imports, source/log/session identity, schemas, frame streams, recovery, scan overview, syncpoint index, range queries, raw series, events, and retained issues.
- `BlackboxAnalysis`: derived series and dedicated calculations such as Spectrum, Step Response, attitude, motor normalization, and automatic timeline range.
- Step Response derives normalized peak, T50, and interpolated 10...90% rise time from each averaged Wiener-deconvolution axis response. The macOS inspector presents these as `Peak`, `T50`, and `tᵣ`; Step Response persistent-cache version 2 invalidates results without rise time.
- Classic Step Response projects its unchanged semantic render model through `StepResponseZoomPolicy.TimeWindow`. Uniform trace sampling makes visible slicing constant-time plus visible-sample drawing; the Canvas retains one neighboring point at each edge. Gesture-local viewport state is isolated from analysis and document storage, then commits one normalized document-wide/preset-portable window at gesture end or per discrete command. Its range-measurement domain follows the visible time window.
- Step Response crosshair state lives in a narrow interaction leaf and draws through a separate constant-work overlay Canvas. Pointer/touch changes therefore invalidate only the vertical line and time chip, not the static trace Canvas, analysis, or persistence. The range-measurement layer remains above it and takes precedence while armed.
- A cancelled Step Response trace computation publishes no partial axis outcomes and writes no failure cache entry. Restore ignores cancellation failures written by the initial version-2 development build so the trace is recomputed once its source/range identity stabilizes.
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

Flight-controller import decisions are layered. `FlightControllerConnectionFlow` derives transfer policy once from the initial contact path plus resolved transport response capability: provenance, configuration capture, extended CLI status permission, and dataflash options. The assistant's `ImportCapabilities` separately derives product methods and option availability from contact path, controller storage, stored-log presence, and Wi-Fi capability. A single post-import deletion flow selects Direct MSP erase, SD-volume deletion, Mass Storage flash replug, or no cleanup. Views consume these resolved states and contain no BLE-profile or chipset policy.

Main-frame time is the primary query axis. Valid auxiliary frames are associated with the active main-frame interval.

## Identity

- `SourceID`: physical imported source.
- `LogID`: one Blackbox segment/session inside a source.
- Full SHA-256: Airframe-document source identity and payload key.
- Ephemeral UUID: runtime document/window identity only.
- Raw document-state identity: versioned content fingerprint; never a persisted source URL.

Do not collapse source, segment, session, and runtime-window identity.

## Documents

### Raw logs

- Read-only `.bbl` and `.bfl`.
- One primary source plus at most eight session-only references.
- UI state persists externally through the bounded document-state repository and iCloud KVS mirror.

### Airframe documents

- Regular `.airframe` files use physical `AirframeContainer` version 1 with an append-only blob/commit structure and logical metadata format version 2.
- The manifest maps ordered log descriptors and normalized SHA-256-keyed source/configuration payloads to immutable container blobs; logical format version 1 remains readable.
- Metadata owns selection, per-source state, names, aircraft settings, import snapshots, and other document state.
- Mutations create coalesced complete metadata snapshots; autosave appends and publishes a new commit without rewriting unchanged payloads.
- Duplicate stages, validates, and atomically publishes a regular container before opening it.

## App Composition

- The iOS/iPadOS target declares a storyboard-free `UILaunchScreen` whose only content is the fixed black `LaunchBackground` color asset (`#000000`), matching the rendered HomeView background. It intentionally has no branding content and does not affect macOS.

- iOS: `WindowGroup` always routes through `HomeView`, including UI-test fixture launches, then owns at most one `AirframeUIDocument` workspace. The document toolbar exposes an explicit Home action that completes the existing flush/platform-close lifecycle before returning to the start surface; close failure leaves the document open and uses the existing error presentation. File-importer selection validates only the supported extension before handing the provider URL to `AirframeUIDocument`; regular-file and container validation occurs after the document starts security-scoped access.
- The iOS/iPadOS empty-recents feature group uses one 680-point three-tile row when that complete row fits and otherwise one complete three-tile column; it never produces a partial row. macOS retains its existing fixed row.
- Overview keeps its fixed adaptive card grid behind the concrete `CardGrid` view boundary. This prevents the container's modifier-heavy body and complete conditional card tree from forming one deeply nested generic type whose runtime metadata instantiation overflows the smaller physical-device arm64 stack; opaque `some View` helpers alone do not create this boundary.
- macOS: `NSDocumentController`/`AirframeNSDocument` plus one start window when no document is visible.
- `FlightControllerImportCompletionCoordinator` keeps assistant acquisition independent from new-document destination, persistence, opening, and post-success temporary cleanup. iOS transfers the payload out of the assistant before presenting `fileExporter`; cancellation restores the same completed assistant state.
- `DefaultFlightControllerImportAssistantRuntime` owns cross-platform discovery aggregation and provider routing. Discovery cancellation preserves the latest route map for selected-device handoff; beginning a new scan replaces it.
- `DocumentHomeView` owns the document `NavigationSplitView`. On iPad its column visibility and preferred compact column are transient UI state, its Sidebar widths are 260/280/340 points, and an explicit Logs action restores the Sidebar; macOS retains persisted column state and its existing widths.
- Sidebar chooses a log; detail chooses Overview, Table, Graph, Spectrum, Step Response, or Map.
- The app-global Show Graph Legend setting controls the multi-series legends in both Graph and Spectrum; axis labels, guide chips, and inspector labels are unaffected.
- Airframe-document log rows read automatic tags from `AirframeWorkspaceController`. Memory or OS-cache hits publish immediately; missing, incompatible, or corrupt entries are rebuilt at utility priority from Reader scan facts and the versioned health report, then written to the device-local `automatic-tags` cache dataset rather than the document.
- On macOS, the document content never sets a navigation or window title. `NSDocument`/AppKit owns the filename title and File Proxy automatically; `LogDataView` sets only the navigation subtitle to the selected log's effective name.
- `EnvironmentValues.airframeLogContext` passes the selected summary, decoded log, analysis workspace, issues, progress, and flight info.
- One document-scoped `ProcessingActivityCounter` wraps and owns all app-side data work. It registers detached worker handles, propagates waiter cancellation, and permanently cancels the registry during document shutdown.
- `AirframeDocumentWindow.close()` is the synchronous macOS UI lifetime boundary: it removes broker actions, resigns first responder, replaces the type-erased hosting root with `EmptyView`, and clears the content controller/view and toolbar before AppKit posts the close. `AirframeNSDocument` then retains itself through asynchronous persistence and performs idempotent final workspace teardown.
- Document teardown is layered and terminal: window close seals global callback registration and removes the SwiftUI hosting root; platform-document close finishes required persistence; document shutdown then cancels `ProcessingActivityCounter`, shuts down document cache actors/adapters, and severs open-model, workspace, persistence, source-byte, decoded-log, history, and snapshot roots. No later SwiftUI callback or completed worker may repopulate a sealed owner.
- One shared timeline position/range drives Table, Graph, playback, and future synchronized media.
- Existing interactive iPad analysis surfaces share touch semantics: tap selects, one-finger drag inspects or scrubs, pinch zooms only an existing viewport, two-finger drag pans only an existing viewport, and double tap resets that viewport without clearing a valid selection. Graph and Spectrum use iOS-native touch adapters while macOS keeps its pointer/trackpad paths; MapKit keeps native gestures and static canvases remain noninteractive.
- Graph playback preserves one exact `DocumentStateStore` cursor while `LogPlaybackController` publishes identity-bound 34 ms secondary-motion and 100 ms readout snapshots. Exact Graph projection/loading, bounded presentation consumers, persistence suspension, overview fallback, and active-surface readiness form one performance contract; the normative rules and review/profile gates live in `Airframe/doc/graph-playback-performance.md`.
- Table playback consumes the identity-bound 100 ms readout snapshot in isolated window/viewport leaves. `Table.Surface` owns loading and cached models without observing the exact cursor; the window leaf publishes parent state only across chunk thresholds, while the viewport owns programmatic/user scroll coordination and delegates stable header and row rendering to child views. Loaded models preindex row identities for constant-time scroll-to-cursor resolution.
- The one-pass Reader overview retains a bounded flight-mode state timeline from slow frames and mode events. Graph resolves the primary Craft-preview mode synchronously at the shared cursor; unavailable or incomplete ranges remain explicitly unknown.

## State

- `DocumentStateStore`: per-window transient state and raw-log restoration.
- `DocumentStateRepository`: bounded content-fingerprint-keyed raw state, mirrored through iCloud KVS.
- `PresetRepository`: observable generation-2 preset library with an immutable synthesized Default, compact local/iCloud KVS storage, and no legacy decoder. `PresetConfiguration` stores portable Graph/Table, Spectrum, Map, and Step/Frequency Response settings. Applying a preset atomically copies the resolved configuration into independent document state; create/overwrite actions snapshot that state back into user presets without changing the document or last-applied preference. Rename preserves preset identity and portable configuration while atomically updating its normalized unique name and timestamp. Batch deletion validates every ID before mutation, emits same-time tombstones, and persists the local/cloud library once.
- `PresetSerialization` owns compact raw preset/override conversion shared by generation-2 library persistence and portable export. `PresetArchiveCodec` owns only the deterministic JSON `.airframepreset` archive envelope (`com.kumkju.airframe.presets`, version 1), which contains one or more user presets and deliberately rejects Default and former single-preset exports.
- `PresetImportWorkflow` decodes an opened archive before mutation, asks its UI adapter to resolve each existing-name conflict, then submits all decisions to one atomic `PresetRepository.importPresets` mutation. Imported records receive fresh local IDs; overwrite retains the selected local ID; keep-both assigns the next available numbered name. Production document stores share `PresetRepository.shared`, so app-level file opening, the management Open panel, and `File > Import Presets…` all update every open preset menu immediately. The macOS command broker routes `View > Manage Presets…` to the active document window.
- `TextInputShortcutGate` observes native AppKit editing sessions application-wide. All Airframe-owned SwiftUI key equivalents go through `airframeKeyboardShortcut`, which removes only the key equivalent while any text input is active; the associated controls remain enabled for pointer and menu interaction. Direct key handlers that could conflict with editing consult the same gate.
- `airframe.presets.lastApplied.v2`: local-only ID of the last manually applied preset. It is used once when a document has no persisted `DocumentStateStore` entry and is never an active-selection marker.
- Generation-1 preset-bound document fields (`graphSetup`, `spectrumSettings`, and `graphWindows`) have no reader or model representation. Package export removes them, and local document-state persistence naturally drops them when rewriting an entry; only rejection/ignore regression fixtures mention them.
- Airframe document metadata: authoritative persistent document state.
- Log-specific document state (timeline position and In/Out range) is addressed by stable source hash plus segment index. Legacy numeric segment keys are read only as fallback; stable keys win and are written on mutation. The transient graph viewport follows the same identity model without being serialized.
- App-global settings: local defaults plus iCloud KVS through `AirframeGlobalSettings`.
- Raw bytes never receive xattrs or app state.

## Presentation

- `AnalysisSeriesCatalog` is the app-facing series catalog.
- Opening a raw log or an embedded `.airframe` source that produces zero readable logs plus Reader issues enters a failed document state with the first localized actionable issue. A package with no readable source derives its empty/error presentation from its embedded-source open states instead of the otherwise idle package shell. Partially readable documents remain open and retain their issue summaries.
- Import scanning isolates each marker-delimited Blackbox candidate. The strict scanner remains available for format validation, while the Reader's recovering scan retains valid segments before and after a malformed candidate, preserves their original candidate indices, and emits a source issue at the skipped candidate's start offset. Global source/segment limits remain fatal.
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
- Graph, Spectrum, Table chunks, analysis workspaces, and prepared Map routes survive log selection changes in document-scoped, log-keyed caches.
- `AirframeWorkspaceController.stageDocumentStateUpdate` coalesces package-backed UI state for one second without delaying domain mutations. It stores only the latest `Metadata.State`, materializes it before every explicit flush or domain mutation, and cancels pending publication during terminal shutdown. `DocumentView` routes both main and reference-log view state through this boundary.
- Spectrum Frequency traces carry an internal exact range-maximum index. Static Canvas projection emits at most one peak per visible pixel bucket; Option-key snapping queries only the two neighboring buckets. P90 summaries and measured motor-frequency guide data prepare off-main through `ProcessingActivityCounter` when semantic inputs change, never from geometry or pointer paths. A macOS Time Profiler acceptance on a 15-minute log confirmed zero static-Canvas, guide-preparation, or full-line-projection work during pointer/snapping updates. The final resize profile reduced `GeometryReader.Child.updateValue` from 910 ms to 168 ms and `filterOverlays` from 637 ms to 93 ms; normalized to static Canvas work, the latter is an approximately 87% reduction despite different manual resize intensity. The shared Spectrum heatmap renderer also passed: pointer movement performed zero static Canvas, guide, model, or bitmap work, while resize reused the prepared bitmap with zero model/image rebuild and only 17 ms attributed directly to heatmap drawing over 15 seconds.
- Spectrum zoom/pan keeps its frequency window local during direct manipulation. Pinch, drag, trackpad, accessibility, menu, and reset paths publish at semantic interaction boundaries; phase-less wheel events coalesce for 250 ms. Trackpad end events are forwarded even when their final delta is zero, and legend/chip geometry publication is equality-gated.
- Frequency Response prepares one immutable surface-owned render model off-main through `ProcessingActivityCounter` per loaded semantic result. The model owns the shared reliable frequency range, compact axis metrics, and already filtered magnitude, unwrapped-phase, sensitivity, and step-response samples. Resize and Canvas drawing only project these values; the existing static plot, guide, and pointer layers retain separate invalidation boundaries. macOS Time Profiler acceptance confirmed zero render-model/range preparation during resize, zero static plot/grid/guide work during Response pointer movement, and zero static heatmap/grid/guide/model/bitmap work during Spectrogram pointer movement.
- Map Timeline prepares the selected route/source into one immutable series that owns samples, domain, grid step, and grid values. Picker availability uses bounded capability checks instead of constructing every series. Only the cursor leaf observes current-position state; the static graph, grid labels, and event markers are a sibling invalidation boundary. A 15-second macOS scrub profile confirmed zero static-layer, series/source, domain, or grid work, with 32 ms attributed to the cursor body and 17 ms to current-value formatting.
- Document-scoped caches live at the document/window composition root, not inside replaceable surfaces and not in process-global registries. Views receive actor references and may request work, but cache/task lifetime is independent from SwiftUI surface identity and ends only at explicit document shutdown.
- Every document cache has a permanent shutdown barrier. After shutdown, lookups miss, stores/publications and task registrations are ignored or cancelled, pending persistence is cancelled, and RAM state is cleared. Memory-pressure trimming is an additional runtime policy, never the close mechanism.
- The process-global persistent store, durable hashed keys, and disk catalog may remain alive after all documents close. Per-document dataset adapters, pending encoded snapshots, source/decoded objects, and RAM results may not. Persistent writes are latest-value coalesced per stable identity and must report zero pending writes at document close.
- Speculative work yields to visible work and is cancelled when its request becomes stale.
- Graph idle preparation uses a stable log/section/zoom/direction identity and exactly two concurrent decode workers to fill overlapping ranges direction-first up to the prepared-series byte budget. It starts after a 20 ms UI-publication yield. The user-initiated worker builds the next ordinary render-ready window; the utility worker merges up to four farther overlapping windows into one larger compact prepared chunk and multiplies its point budget by the duration ratio. A later background hit is binary-sliced to the ordinary request range before building a render model. Persistent publication is scoped across the frontier and coalesced after it becomes quiescent.
- Graph's overview tier is a display fallback, not a reason to ignore a covering prepared-detail cache entry. During scrubbing and playback, prepared detail can be projected immediately. The resulting render model is keyed by the intersection of the requested load range and the prepared entry's real range; the entry is only required to cover the viewport, so claiming the full wider request creates false coverage and blank playback regions. When current detail loses complete viewport coverage, overview keeps the plot populated until the replacement is published.
- Graph render models are retained by approximate byte cost in one document-scoped global LRU, not by a fixed entry count. Normal/pressure targets are 192/64 MB on macOS and 64/24 MB on iOS. This permits many small zoomed windows to survive a complete playback while still bounding live-document memory, reacting to memory pressure, and clearing terminally at document shutdown.
- `GraphCacheCoverageState` is owned beside the document's Graph caches and observes range-only mutations from prepared-series and render-model stores, including disk restore, eviction, memory pressure, and shutdown. `Graph.Surface` adds active shape, in-flight worker, and displayed-detail state. `LogTimeline` renders loading, prepared, and render-ready coverage in a separate three-point opaque bottom `GraphCacheCoverageStrip`; it never retains cache payloads, counts full-log overview as detail availability, or adds another color for the active viewport already indicated by the Timeline. A solid dark-gray baseline makes an empty coverage state visibly distinct from a missing strip. Graph and Timeline join this projection through the window-unique `LogContext.cacheLogID`; the raw decoded-log ID is not a valid cache key because reference/source logs can collide and are intentionally remapped.
- Shared Timeline In/Out overlays resolve through `LogContext.stateKey`, exactly like current position, toolbar editing, playback, and Graph. A raw segment index is only a legacy persistence fallback and must not be used as the active UI identity.
- Graph Canvas drawing binary-slices sorted points to the visible interval plus one neighbor per edge and walks sorted gaps linearly, keeping playback redraw work bounded by visible geometry.
- Memory pressure trims caches by priority while protecting the currently visible model.
- `AirframeCache` owns the OS-cache-directory store, binary integrity envelope, SQLite LRU catalog, quota enforcement, usage metrics, and explicit clearing. App adapters define dataset-specific payloads and static cache versions.
- Persistent cache operations use the `airframe.cache` unified-log category. Messages identify dataset, static version, a short hashed key, and byte counts without exposing source bytes, filenames, or full cache paths.
- Package-backed data uses separate versioned datasets for Reader scans, Overview snapshots, health reports, automatic tags, Table frame chunks, prepared Graph series, Craft timelines, center-of-gravity estimates, Spectrum frequency/heatmap/RPM-notch results, filter delay, Step Response, and Frequency Response. Raw files and session-only references remain memory-only; missing OS-purged files are ordinary misses.
- Map routes and Timeline projections remain RAM-only because they are cheap bounded projections of the persisted Reader scan; final UI render models remain RAM-only because they are cheap projections of persisted semantic results.

## Transient X-Range Measurement

- `AnalysisRangeMeasurementState` is owned by `LogDataView` and injected through the environment. It contains only the committed domain range, bounded results, generation state, surface readiness, and the iPad one-shot arm flag. The high-frequency drag draft is owned by the interactive overlay leaf, deduplicated, and coalesced to at most 120 publications per second, so pointer movement cannot invalidate the environment or sibling chart canvases.
- `AirframeUI` owns platform-native `AxisRangeSelectionTrackingView`, normalized drag projection, and the data-independent band overlay. macOS hit testing activates only for Option-started drags; iPadOS activates only while armed.
- The measurement geometry shell maps immutable plot/domain metadata and passes it into the draft-observing leaf; draft publications do not rebuild pane domains. The visible band uses bounded SwiftUI rectangles instead of a chart-sized `Canvas`, and its chip text is formatted once per published draft with a retained formatter.
- Each supported surface maps one plot rectangle and linear/logarithmic domain per visible section/pane, owns/cancels its calculation through a stable non-observable task owner, runs work through `ProcessingActivityCounter`, and publishes only when the generation is current. Installing or cancelling the underlying task does not invalidate the surface. The drag-start pane ID scopes both overlay and series extraction; Frequency Response additionally keeps frequency and time domains from crossing.
- Each bounded series result carries the same semantic color role as its rendered trace. The shared inspector resolves that role through the AirframeUI spectrum palette, displays only the series label (the selected pane already supplies context), and attaches localized native help/accessibility hints to its compact metric rows.
- `BlackboxAnalysisWorkspace.seriesStatistics` walks `ReaderMainFrameChunkDirectory` twice, one bounded chunk at a time: the first pass obtains exact statistics and the selected series span, and the second extracts prominent extrema. It shares `AnalysisSeriesStatisticsAccumulator` with prepared Step/Spectrum/Frequency Response curves and never materializes the selected Graph range.
- The extrema reducer requires reversal prominence equal to the larger of the presentation tolerance and 5% of the selected series span. It retains a pending extremum plus one tentative opposite, replaces same-kind candidates with the stronger one, and thereby suppresses raw-sample ripple without field-specific thresholds. It consumes out-of-selection neighbors only as direction context; only selected extrema enter counts and period moments.

## Testing

- Swift Testing for packages; XCTest where platform facilities require it.
- Golden compact fixtures for headers, frame streams, events, range queries, and corruption behavior.
- Representative multi-log, GPS, and damaged/truncated fixtures.
- Parser tests assert deterministic typed failures and configured-budget enforcement.
- App tests cover document/package invariants, state routing, commands, and view-model behavior.
- External oracle comparison is supplementary, not the source of implementation structure.

## Log Health Checks

- `BlackboxAnalysis/Health/` owns plausibility checks beyond `ReaderLogQuality`: `BlackboxAnalysisWorkspace.healthReport(using:)` aggregates typed `AnalysisHealthFinding`s (motorPolesMismatch, motorDesync, logDataGaps, erpmWithoutRPMFilter, batteryChargeLowAtArm) plus first-class skip reasons.
- `BlackboxAnalysis/AutomaticTags/` projects scan facts, `ReaderLogQuality`, and `AnalysisHealthReport` into the four cached analysis tag IDs. `BlackboxReader` centrally owns version-aware flight-mode bit names, full-scan Chirp evidence, and the shared GPS route-usability predicate. The app adds the `Config` data tag live when the same Flight Controller import snapshot directly links the source hash to a valid configuration payload; configuration fallback resolution is deliberately excluded.
- The motor-poles detector reuses the `.frequencyVsRPM` sample buffer (one decode pass), chunked FFTs, and a robust median-ratio estimator. Precision comes from the RPM-span guard (fixed resonances produce RPM-dependent ratios) and the even-pole snap tolerance (2 %), not from the dispersion gates: on real quads every motor's search window latches onto the strongest ridge, so observation scatter equals the motors' RPM spread (~5 %).
- Reports persist per source segment in the device-local `health` cache dataset; the cache key includes the health algorithm identity and the dataset has its own static format version. Raw logs keep reports in memory on `AirframeWorkspaceController.healthReports`.
- The Overview container runs the checks in a deferred background task (1 s settle, `ProcessingActivityCounter`, utility priority) after cache lookup; the `ChecksCard` in the card grid shows its header spinner while this uncached health task is active. It renders Log Quality plus compact finding rows (severity icon, short value like `12 vs. 14`) with the full explanation as a tooltip via `overviewTooltip`.
