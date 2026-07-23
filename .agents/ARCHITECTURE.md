# Current Architecture

This file describes the current technical shape. Stable product and workflow rules live in `MEMORY.md`; future ideas live in `BACKLOG.md`.

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

- `BlackboxCore`: byte streams, encodings, predictors, frame primitives, and typed parser failures.
- `BlackboxReader`: imports, source/log/session identity, schemas, frame streams, recovery, scan overview, syncpoint index, range queries, raw series, events, and retained issues.
- `BlackboxAnalysis`: derived series and dedicated calculations such as Spectrum, Step Response, attitude, motor normalization, and automatic timeline range.
- `AirframeCaptions`: typed localization over domain semantic IDs.
- `AirframeUnits`: focused locale-aware numeric and unit formatting.
- `AirframeUI`: reusable data-driven rendering and display models without app navigation ownership.
- App target: document lifecycle, state routing, windows, menus, navigation, settings, and composed views.
- `AirframeCLI`: human and machine-readable inspection/export over Reader and Analysis APIs.

Dependencies point downward. Domain packages never depend on captions, SwiftUI, app state, or the processing activity counter.

## Data Flow

1. Import preserves physical source-file identity.
2. Reader discovers one or more Blackbox log segments per source.
3. One scan produces summary, issues, syncpoints, events, and a bounded overview.
4. Indexed queries decode full-resolution data for requested time ranges.
5. Analysis maps Reader series to display-scaled or derived series.
6. App/UI consumers build bounded render models and cache them per document.

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
- Ordered equal `logs` descriptors and SHA-256-keyed byte-identical payloads.
- Metadata owns selection, per-source state, names, and other package UI state.
- Mutations create coalesced snapshots and explicit silent saves.
- Physical duplicate coordinates, copies, validates, then opens the package.

## App Composition

- iOS: `WindowGroup` → `HomeView` → one `AirframeUIDocument` workspace.
- macOS: `NSDocumentController`/`AirframeNSDocument` plus one start window when no document is visible.
- `DocumentHomeView` owns the document `NavigationSplitView`.
- Sidebar chooses a log; detail chooses Overview, Table, Graph, Spectrum, or Step Response.
- `EnvironmentValues.airframeLogContext` passes the selected summary, decoded log, analysis workspace, issues, progress, and flight info.
- One document-scoped `ProcessingActivityCounter` wraps all app-side data work.
- One shared timeline position/range drives Table, Graph, playback, and future synchronized media.

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
