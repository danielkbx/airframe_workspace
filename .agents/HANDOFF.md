# Handoff: Next Reader Batch

## Purpose

Use this file as the starting point for the next chat.

The next task is to implement the independent Reader consumer layer:

1. `ReaderSeriesCatalog`
2. `ReaderSeriesTable`
3. `ReaderViewportSeries`
4. `ReaderSeriesCSV`
5. `ReaderSeriesRequest`

This is a package-only `BlackboxReader` batch. Do not build app/UI targets.

## Current State

Project root:

- `/Users/daniel/Projekte/Blackbox`

Active package work:

- `Airframe/Packages/BlackboxCore`
- `Airframe/Packages/BlackboxReader`

Do not modify:

- `blackbox-log-viewer/`
- `betaflight/`

The workspace root is not a git repository.

Current verified package state:

- `BlackboxCore`: 87 Swift Testing tests in 10 suites.
- `BlackboxReader`: 104 Swift Testing tests in 12 suites.
- `swift test` and `swift build` passed for both packages after the flight-info and field-range slice.

Existing important Reader APIs:

- Header QuickLook:
  - `ReaderHeaderPreviewOptions`
  - `ReaderHeaderPreview`
  - `DecodedLogHeaderInfo`
  - `DecodedLog.headerInfo`
  - `BlackboxReader.headerInfos(in:)`
  - `BlackboxReader.previewHeaders(fileAt:options:)`
- Scan / metadata:
  - `DecodedLogSummary`
  - `ReaderLogIndex`
  - `DecodedLogScan`
  - `DecodedLog.summarize()`
  - `DecodedLog.makeIndex()`
  - `DecodedLog.scan()`
  - `DecodedLogFlightInfo`
  - `DecodedLog.flightInfo(using:)`
  - `BlackboxReader.flightInfos(in:)`
- Range APIs:
  - `ReaderMainFrameRange`
  - `DecodedLog.mainFrames(fromMainFrameTime:throughMainFrameTime:using:)`
  - `ReaderFrameRange`
  - `DecodedLog.allFrames(fromMainFrameTime:throughMainFrameTime:using:)`
  - `ReaderFieldSelector`
  - `ReaderFieldSample`
  - `ReaderFieldRange`
  - `DecodedLog.mainFrameFields(...)`

## Durable Direction

Do not mirror upstream architecture or naming.

Use upstream only as a behavioral sanity reference. Prefer independent Swift-native Reader concepts optimized for speed, robustness, and explicit data identity.

Avoid upstream-style concepts:

- `FlightLog`
- `MainFieldNames`
- `[all]`
- `friendlyName`
- `GraphConfig`
- merged synthetic main stream

The new layer should use `ReaderSeries*` terminology.

CSV is wanted, but it must be a leaf export/debug encoder over typed data, not the internal model.

## Batch Plan

### Phase 1: ReaderSeriesCatalog

Add file:

- `Airframe/Packages/BlackboxReader/Sources/BlackboxReader/ReaderSeriesCatalog.swift`

Public types:

```swift
public struct ReaderSeriesID: Equatable, Hashable, Sendable {
    public let marker: String
    public let fieldName: String
    public let fieldIndex: Int
}

public struct ReaderSeriesDescriptor: Equatable, Sendable {
    public let id: ReaderSeriesID
    public let isMainFrameQueryable: Bool
}

public struct ReaderSeriesFrameGroup: Equatable, Sendable {
    public let marker: String
    public let series: [ReaderSeriesDescriptor]
}

public struct ReaderSeriesCatalog: Equatable, Sendable {
    public let logID: LogID
    public let sourceID: SourceID
    public let groups: [ReaderSeriesFrameGroup]
    public let mainFrameSeries: [ReaderSeriesDescriptor]
}
```

Add to `DecodedLog`:

```swift
public var seriesCatalog: ReaderSeriesCatalog { get }
```

Behavior:

- Build from `DecodedLog.schema`.
- No scan, frame decoding, or file I/O.
- Groups sorted by marker.
- Series sorted by `fieldIndex`.
- `isMainFrameQueryable == true` only for markers `"I"` and `"P"` in v1.
- Optional markers such as `"S"`, `"G"`, `"H"` may appear in `groups`, but not in `mainFrameSeries`.

Helpers:

```swift
public func descriptor(for id: ReaderSeriesID) -> ReaderSeriesDescriptor?
public func descriptors(for marker: String) -> [ReaderSeriesDescriptor]
public func selector(marker: String, fieldName: String) -> ReaderSeriesSelector?
```

`selector(marker:fieldName:)` returns `nil` if missing or ambiguous.

### Phase 2: ReaderSeriesTable

Add file:

- `Airframe/Packages/BlackboxReader/Sources/BlackboxReader/ReaderSeriesTable.swift`

Public types:

```swift
public struct ReaderSeriesSelector: Equatable, Hashable, Sendable {
    public let id: ReaderSeriesID
}

public struct ReaderSeriesColumn: Equatable, Hashable, Sendable {
    public let selector: ReaderSeriesSelector
}

public enum ReaderSeriesCell: Equatable, Sendable {
    case integer(Int)
    case missing
}

public struct ReaderSeriesRow: Equatable, Sendable {
    public let mainFrameTime: Int
    public let marker: String
    public let byteRange: Range<Int>
    public let values: [ReaderSeriesSelector: ReaderSeriesCell]
}

public struct ReaderSeriesTable: Equatable, Sendable {
    public let logID: LogID
    public let sourceID: SourceID
    public let requestedStartMainFrameTime: Int
    public let requestedEndMainFrameTime: Int
    public let columns: [ReaderSeriesColumn]
    public let rows: [ReaderSeriesRow]
    public let issueCount: Int
    public let issues: [ReaderIssue]
}
```

Errors:

```swift
extension ReaderSeriesTable {
    public enum Error: Swift.Error, Equatable {
        case duplicateSelector(ReaderSeriesSelector)
        case unsupportedSeries(ReaderSeriesSelector)
        case nonMainFrameSeries(ReaderSeriesSelector)
        case ambiguousSeriesName(marker: String, fieldName: String)
        case fieldRangeLogMismatch(expected: LogID, actual: LogID)
    }
}
```

Add to `DecodedLog`:

```swift
public func seriesTable(
    from fieldRange: ReaderFieldRange,
    selectors: [ReaderSeriesSelector]
) throws -> ReaderSeriesTable

public func mainFrameSeriesTable(
    _ selectors: [ReaderSeriesSelector],
    fromMainFrameTime startTime: Int,
    throughMainFrameTime endTime: Int,
    using index: ReaderLogIndex? = nil
) throws -> ReaderSeriesTable
```

Behavior:

- Validate `fieldRange.logID == id`.
- Validate selectors are unique.
- Validate selectors exist in `seriesCatalog`.
- `mainFrameSeriesTable(...)` rejects selectors where `isMainFrameQueryable == false`.
- Convert selectors to existing `ReaderFieldSelector(marker:name)`.
- Call existing `mainFrameFields(...)`.
- Emit `.integer(value)` or `.missing` per cell.
- Preserve issue metadata from `ReaderFieldRange`.

### Phase 3: ReaderViewportSeries

Add file:

- `Airframe/Packages/BlackboxReader/Sources/BlackboxReader/ReaderViewportSeries.swift`

Public types:

```swift
public enum ReaderViewportSamplingMode: Equatable, Sendable {
    case exact
    case minMaxBuckets
}

public struct ReaderViewportRequest: Equatable, Sendable {
    public let selectors: [ReaderSeriesSelector]
    public let startMainFrameTime: Int
    public let endMainFrameTime: Int
    public let maximumPointsPerSeries: Int
    public let samplingMode: ReaderViewportSamplingMode
}

public enum ReaderViewportPointKind: Equatable, Sendable {
    case exact
    case bucketMinimum
    case bucketMaximum
}

public struct ReaderViewportPoint: Equatable, Sendable {
    public let mainFrameTime: Int
    public let value: Int
    public let byteRange: Range<Int>
    public let kind: ReaderViewportPointKind
}

public struct ReaderViewportSeries: Equatable, Sendable {
    public let selector: ReaderSeriesSelector
    public let points: [ReaderViewportPoint]
}

public struct ReaderViewportResult: Equatable, Sendable {
    public let logID: LogID
    public let sourceID: SourceID
    public let requestedStartMainFrameTime: Int
    public let requestedEndMainFrameTime: Int
    public let maximumPointsPerSeries: Int
    public let samplingMode: ReaderViewportSamplingMode
    public let series: [ReaderViewportSeries]
    public let issueCount: Int
    public let issues: [ReaderIssue]
}
```

Error:

```swift
extension ReaderViewportResult {
    public enum Error: Swift.Error, Equatable {
        case invalidPointLimit(Int)
    }
}
```

Add to `DecodedLog`:

```swift
public func viewportSeries(
    for request: ReaderViewportRequest,
    using index: ReaderLogIndex? = nil
) throws -> ReaderViewportResult
```

Behavior:

- Reject `maximumPointsPerSeries <= 0`.
- Build `ReaderSeriesTable`.
- `.exact` returns all non-missing points.
- `.minMaxBuckets` bounds point count per series while preserving local extrema.
- Preserve issues and requested range metadata.

### Phase 4: ReaderSeriesCSV

Add file:

- `Airframe/Packages/BlackboxReader/Sources/BlackboxReader/ReaderSeriesCSV.swift`

Public types:

```swift
public struct ReaderSeriesCSVOptions: Equatable, Sendable {
    public let columnDelimiter: String
    public let lineDelimiter: String
    public let includeHeaderRow: Bool
    public let missingValue: String

    public static let standard: ReaderSeriesCSVOptions
}

public struct ReaderSeriesCSVDocument: Equatable, Sendable {
    public let text: String
    public let rowCount: Int
    public let columnCount: Int
}

public enum ReaderSeriesCSV {
    public static func encode(
        _ table: ReaderSeriesTable,
        options: ReaderSeriesCSVOptions = .standard
    ) -> ReaderSeriesCSVDocument
}
```

Default options:

```swift
.standard = ReaderSeriesCSVOptions(
    columnDelimiter: ",",
    lineDelimiter: "\n",
    includeHeaderRow: true,
    missingValue: ""
)
```

Columns:

1. `mainFrameTime`
2. `marker`
3. `byteStart`
4. `byteEnd`
5. one column per selected series

Series column name format:

```text
series.<marker>.<fieldIndex>.<fieldName>
```

Escaping:

- Quote cells containing delimiter, quote, CR, or LF.
- Escape `"` as `""`.
- Missing cells use `options.missingValue`.
- Integers remain raw decimal strings.
- No file writing in this slice.

Add to `DecodedLog`:

```swift
public func seriesCSV(
    from table: ReaderSeriesTable,
    options: ReaderSeriesCSVOptions = .standard
) -> ReaderSeriesCSVDocument
```

### Phase 5: ReaderSeriesRequest

Add file:

- `Airframe/Packages/BlackboxReader/Sources/BlackboxReader/ReaderSeriesRequest.swift`

Public type:

```swift
public struct ReaderSeriesRequest: Equatable, Sendable {
    public let selectors: [ReaderSeriesSelector]
    public let startMainFrameTime: Int
    public let endMainFrameTime: Int
}
```

Add to `DecodedLog`:

```swift
public func seriesTable(
    for request: ReaderSeriesRequest,
    using index: ReaderLogIndex? = nil
) throws -> ReaderSeriesTable

public func seriesCSV(
    for request: ReaderSeriesRequest,
    using index: ReaderLogIndex? = nil,
    options: ReaderSeriesCSVOptions = .standard
) throws -> ReaderSeriesCSVDocument
```

Behavior:

- `seriesTable(for:)` calls `mainFrameSeriesTable(...)`.
- `seriesCSV(for:)` calls `seriesTable(for:)`, then `ReaderSeriesCSV.encode(...)`.

## Tests To Add

Add these files:

- `BlackboxReaderSeriesCatalogTests.swift`
- `BlackboxReaderSeriesTableTests.swift`
- `BlackboxReaderViewportSeriesTests.swift`
- `BlackboxReaderSeriesCSVTests.swift`

Required test scenarios:

- Catalog lists `I`/`P` fields from `single-log-basic`.
- Catalog keeps optional `G`/`H` markers separate in `gps-home-flow`.
- Catalog lookup is exact.
- Catalog generation does not consume stream state.
- Series table projects `ReaderFieldRange` into typed rows.
- Missing values are represented as `.missing`.
- Duplicate, unsupported, non-main-frame, and mismatched-log selectors throw explicit errors.
- Empty ranges produce columns and zero rows.
- Viewport exact mode emits all non-missing points.
- Viewport min/max mode bounds points and preserves extrema.
- Invalid viewport point limit throws.
- CSV includes header row by default.
- CSV metadata columns come first.
- CSV writes raw integer cells.
- CSV writes missing cells using `missingValue`.
- CSV escaping handles delimiter, quotes, CR, and LF.
- CSV without header row works.
- High-level request APIs match lower-level explicit calls.

## Local Smoke

Use a temporary runner under:

- `/tmp/airframe-series-smoke`

It should:

- Open `Flightlogs/small/*`.
- Build `scan`.
- Build `seriesCatalog`.
- Select available:
  - `I/time`
  - `I/gyroADC[0]`
  - `P/time`
  - `P/gyroADC[0]`
- Build a `ReaderSeriesRequest`.
- Produce:
  - `ReaderSeriesTable`
  - `ReaderViewportResult`
  - `ReaderSeriesCSVDocument`
- Print:
  - source name
  - catalog group count
  - main-frame-queryable series count
  - table row count
  - viewport point count
  - CSV row count
  - issue count

Do not commit the smoke runner.

## Verification

Run:

```bash
cd "/Users/daniel/Projekte/Blackbox/Airframe/Packages/BlackboxReader"
swift test
swift build

cd "/Users/daniel/Projekte/Blackbox/Airframe/Packages/BlackboxCore"
swift test
swift build
```

Expected:

- Existing behavior remains unchanged.
- Reader test count increases beyond current `104` tests / `12` suites.
- No changes to `blackbox-log-viewer/` or `betaflight/`.
- No UI/app target changes.
- No external dependencies.

## Agent Notes To Update After Implementation

Update:

- `.agents/PLAN.md`
- `.agents/TASKS.md`
- `.agents/ARCHITECTURE.md`
- `.agents/MEMORY.md`

Add durable rule:

> Do not mirror upstream architecture or naming. Use upstream only as a behavioral sanity reference. Prefer independent Swift-native Reader concepts optimized for speed, robustness, and explicit data identity.

## After This Batch

After this batch, a first consumer can be built:

- QuickLook/preview consumer via `previewHeaders(fileAt:)`
- Flight overview via `flightInfo(using:)`
- Series picker via `seriesCatalog`
- Chart data via `viewportSeries(...)`
- Inspector table via `seriesTable(...)`
- CSV/export/debug via `seriesCSV(...)`

The recommended next step after this batch is a minimal native chart prototype that consumes `ReaderViewportResult` directly.
