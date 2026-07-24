# Project Memory

This file stores durable decisions and constraints. It intentionally omits implementation diaries, commit lists, and test transcripts.

## Product

- Name: Airframe.
- Subtitle: A Blackbox Log Analyzer.
- Native Swift Universal app for iOS and macOS.
- Swift-native parser and model; no WebView wrapper.
- App Store distribution is optional.
- Project language is English for code, documentation, comments, commits, and artifacts.
- Build an independent implementation. Reference upstream behavior and formats, but do not translate source structure or implementation text.
- GPL-3.0 is acceptable if required, but the final license is not chosen.

## Repository Boundaries

- Workspace root: private wrapper repository `danielkbx/airframe_workspace`, branch `master`.
- `Airframe/`: public project submodule `danielkbx/airframe`; commit only with explicit user approval.
- `blackbox-log-viewer/`, `betaflight/`, `betaflight-configurator/`, and `PIDtoolbox/`: read-only reference submodules; never commit or push from this workspace.
- `betaflight-configurator/` is intentionally pinned at `14a050b7b57b4addadc209e5b67b3cfd9fdef943` for flight-controller import reference work.
- Durable private context lives in `.agents/`.
- Never put AI or automation attribution in `Airframe/`, public documentation, commits, PR titles, or PR descriptions.

## Development Rules

- Planning only unless the user requests implementation.
- No external dependencies without explicit approval. `swift-argument-parser` is already approved for `AirframeCLI`.
- Use Swift 5.9 language mode and modern Swift idioms.
- Prefer async/await and structured concurrency.
- Prefer Swift Testing for packages; XCTest is allowed for app tests, UI automation, and Xcode-specific facilities.
- Use Semantic Versioning. Every package and Xcode target shares one version; Xcode targets inherit `MARKETING_VERSION` from `Base.xcconfig`.
- Use typed, domain-specific errors and `throws` rather than Swift `Result` return values.
- Keep large types in separate files; compact local subordinate types may remain with their owner.
- One-line calls and declarations are preferred when they fit within 150 characters.
- Project file headers use `SPDX-FileCopyrightText: 2026 mail@danielkbx.com`. Do not add a license identifier before the license is chosen.

## Safety And Performance

- Treat every input byte, header, frame definition, event payload, and caller option as hostile.
- Validate bounds and configured budgets before reads, allocation, iteration, or filesystem work.
- Malformed input must produce typed errors, retained issues, or compatibility blocking; never crashes, overflow traps, unbounded loops, or unbounded allocations.
- Keep parser primitives allocation-conscious and suitable for later streaming.
- Whole-flight acquisition should reuse the one-pass scan overview. Full-resolution work should use indexed range queries.
- App-side data processing must run through the per-document `ProcessingActivityCounter`; domain packages remain unaware of UI activity tracking.

## Package And App Boundaries

- Swift packages live under `Airframe/Packages/`.
- Core packages:
  - `BlackboxCore`: parser primitives only.
  - `BlackboxReader`: file/log structure, decoding, recovery, indexing, range queries, and raw series.
  - `BlackboxAnalysis`: derived analysis and app-facing analysis workspaces.
  - `AirframeCaptions`: all user-facing localized strings.
  - `AirframeUnits`: focused locale-aware unit formatting.
  - `AirframeUI`: reusable data-driven UI, charts, and display models.
  - `AirframeCLI`: CLI kit plus thin `airframe` executable.
  - `Logging`: local dependency-free logging infrastructure.
  - `MSP`: transport-independent MSP v1/v2 framing, streaming decode, request coordination, and CLI framing.
  - `FlightController`: Betaflight-specific discovery, transports, handshake, dataflash, CLI, settings, and file-backed import payloads.
- App-specific navigation, documents, window lifecycle, menus, and composed screens remain in the app target.
- Domain packages must not depend on `AirframeCaptions`; consumers combine semantic IDs with captions.
- `MSP` uses the local `Logging` package category `msp.protocol` for direction, version, code, byte counts, retries, failures, and connection lifecycle. It never logs MSP payload bytes or CLI command/response text.
- `FlightController` owns transport-neutral discovery and byte-transport protocols plus the Betaflight handshake. It accepts MSP API 1.44 through 1.48, marks newer API 1.x versions as untested, and rejects non-`BTFL` variants.
- `FlightController` logs handshake stages, lifecycle, and dataflash metadata through `flight-controller.protocol`; it never logs payload bytes or device identifiers.

## User-Facing Text

- Every user-facing label, title, caption, event name, issue message, placeholder, menu item, and accessibility string is owned by `AirframeCaptions` and backed by `.xcstrings`.
- Raw log values, filenames, numeric values, debug-only test names, internal IDs, and machine-readable JSON keys are exceptions.
- User-facing numeric output uses focused locale-aware formatters; units belong in headers, not every numeric cell.
- Public comments explain the format or local design directly and do not cite upstream implementation choices.

## Documents

- The app registers raw `.bbl` and `.bfl` files plus Airframe package documents. `.txt` and `.log` are not system-wide document types.
- Raw logs are read-only and never modified.
- `AirframeWorkspaceDocument` is the shared model for raw logs and `.airframe` packages.
- Package format version 2 contains `metadata.json`, byte-identical source payloads stored under SHA-256-derived paths, ordered flight-controller import snapshots, and content-addressed CLI configurations under `flight-controller/config/<sha256>.txt`.
- Version-1 packages remain readable and keep their original format version until a real mutation occurs.
- `FlightControllerImportPayload` is independent of document creation. `AirframeImportMaterializer` uses one atomic mutation for both new-package creation and append; duplicate-only imports are complete no-ops, while configuration-only payloads can extend existing packages.
- Package metadata uses one ordered `logs` array. All embedded sources are equal; there is no persistent main/reference distinction.
- Package validation requires at least one source, unique full hashes and paths, safe relative paths, and matching byte counts and SHA-256 hashes.
- Package source order is insertion order and drives global `Log N` numbering. Sources append; reorder UI does not exist.
- Packages have no fixed source limit. Raw windows may hold one main log plus at most eight temporary references.
- Package state is authoritative in `metadata.json`. Raw-log state remains in the external document-state repository and seeds package state once during conversion.
- Package mutations are coalesced and silently persisted. Closing or replacing a workspace flushes pending changes; failed writes remain pending for retry.
- Airframe documents have no persistent document UUID. Runtime windows use ephemeral identity; source/cache identity uses full SHA-256.
- Bookmarks are deliberately absent from format version 1 until behavior and types are designed.
- macOS native Save, Save As, and Revert remain disabled. Duplicate is a coordinated byte-preserving filesystem copy; Rename and Move remain available for packages.

## Document Entry And Presentation

- iOS uses one `HomeView` workspace and `AirframeUIDocument`; macOS uses `AirframeNSDocument` windows plus one non-document start window.
- The shared start view offers Open Log, folder import, and the staged Flight Controller Import Assistant.
- Raw-log opening policy is iCloud-synced and offers `Ask` or `Always Open Read-Only`.
- Conversion language says `Airframe document`, not `editable document`.
- Package sidebars flatten all source segments into one `Logs` section. Raw sidebars preserve file/log/reference hierarchy.
- Package source names may be customized per segment without changing bytes, hashes, parser titles, or original filenames.
- Effective package names are used consistently in navigation, Graph/Spectrum, and Step Response.
- Source removal is context-menu-only. Raw removal detaches without deleting the original file; package deletion removes embedded bytes and all contained logs from the document.

## UI Architecture

- `DocumentHomeView` owns document composition and the stable `NavigationSplitView`.
- The sidebar is contextual navigation; the selected log's data belongs in the detail area.
- Current views are Overview, Table, Graph, Spectrum, and Step Response.
- Table and Graph share one timeline position/range and one playback transport. Future video must synchronize to this master transport.
- Table, Graph, Spectrum, and Step Response use reusable data-processing stages and document-scoped caches.
- Per-window transient UI state lives in `DocumentStateStore`. Package-persistent state lives in metadata.
- SwiftUI view files in the app target and `AirframeUI` require at least one realistic `#if DEBUG` preview using production model types.
- Every selectable Reader or Analysis series needs semantic classification, caption, unit, conversion, precision, raw fallback, and focused tests before UI exposure.

## Git And GitHub

- Root workspace commits may be short, frequent, and attribution-free.
- Never commit in `Airframe/` without explicit user approval.
- Never commit or push reference submodules.
- Use `gh` with account `danielkbx`; verify the active account before every push or PR action.
- Do not use Conventional Commit prefixes.
- Current feature work uses `feature/flight-controller-import` in both the private workspace and public Airframe repository.
- Flight-controller import advances one reviewed commit at a time; do not begin the next milestone before explicit user approval.

## Flight Controller Import

- Direct FC import is approved as a staged feature.
- macOS supports direct USB serial and BLE; iOS/iPadOS support BLE only.
- The assistant flow is Prepare, Device, Connect, Content, and Import. It returns a reusable file-backed payload rather than creating a document itself.
- The assistant shell is driven by a testable app-side state machine. macOS device selection prefers USB and otherwise selects the strongest BLE device; iOS selects the strongest BLE device.
- The first release reads onboard FlashFS through MSP and can save a CLI `dump`. MSP SD-card file download is unavailable.
- macOS USB discovery uses IOKit USB serial callout devices and opaque stable IDs. Serial I/O uses `/dev/cu.*` at 115200 8N1 raw mode on a dedicated queue.
- The USB path is hardware-validated with a sandboxed SpeedyBee F405 V5 running Betaflight 4.5.2. Build revision fields are printable seven-byte ASCII and may contain `norevis`, not only Git hex.
- FlashFS download uses uncompressed 4,096-byte MSP v1 jumbo reads, writes validated bytes directly to a temporary file, reports byte-derived progress, and retries a timed-out chunk once. Normal downloads remove partial files on final failure or cancellation; explicit resume mode preserves confirmed partial bytes.
- Configuration download uses framed STX/ETX CLI on Betaflight 4.5.4 and newer. Older firmware uses interactive CLI, recognizes either the batch-end marker or a settled terminal prompt after a verified dump header, then exits and treats the rebooting serial connection as disconnected.
- MSP and CLI logs contain only lifecycle, command/frame metadata, byte counts, retries, and failures. Configuration contents, payload bytes, destination paths, and device identifiers are never logged.
- Production discovery must never inject mock devices. Preview mocks are compiled only in Debug.
- Serial transports can only be created from a currently discovered provider-owned device mapping; the app does not accept user-provided device paths.
- BLE discovery scans without a CoreBluetooth service filter because SpeedyBee Adapter 3 may omit service UUIDs and a usable name from advertisements. It publishes every discovered BLE peripheral in replacement snapshots keyed by opaque CoreBluetooth UUIDs with structured RSSI signal strength; support validation is deferred until after connection.
- BLE mappings carry ordered profile candidates. Advertised matches lead, followed by deterministic SpeedyBee, CC2541, HM-10, Nordic UART, DroneBridge, and HC-05 fallbacks matching the pinned Configurator. After connecting, CoreBluetooth discovers all primary services, resolves the actual known candidate, and only then discovers that profile's characteristics; unsupported peripherals fail with `serviceUnavailable` and disconnect.
- BLE service resolution normalizes 16-bit, 32-bit, and full 128-bit Bluetooth UUID forms. CoreBluetooth reports the hardware-validated SpeedyBee V2 service as short `ABF0`, while the profile registry stores its full base UUID.
- BLE devices carry an advisory `isLikelyFlightController` hint without affecting discovery eligibility. Known advertised profiles, normalized `SpeedyBee`/`SBADAPTER…` names, and common FC MCU prefixes such as F405, F722, H743, and G474 are suggested; USB is always suggested.
- The import assistant defaults to suggested devices when any exist and offers `Show All Bluetooth Devices` when other BLE devices are hidden. Showing all never restarts discovery; hiding all again moves a hidden selection to the preferred visible USB or strongest suggested BLE device.
- BLE discovery owns at most one nonterminal transport actor per currently mapped peripheral/profile. Repeated creation requests reuse it; a finished transport is replaced for retry, while disappearance or profile change drops the provider cache entry.
- BLE connection success requires service/characteristic discovery and notification enablement. Writes are single-flight across their full chunk sequence, use CoreBluetooth maximum-length chunking, prefer write-without-response with readiness backpressure, and fall back to write-with-response.
- The default import runtime merges USB and BLE replacement snapshots on macOS and exposes BLE snapshots on iOS/iPadOS. It emits an initial empty snapshot synchronously, orders USB before BLE and then by stable name/qualified ID, suppresses unchanged aggregates, and isolates each discovery source's completion or failure.
- Assistant device IDs are provider-qualified. The runtime retains the exact provider-owned `FlightControllerDevice` route instead of reconstructing it from presentation data; canceling discovery preserves the selected route for connection handoff, while a new scan clears prior routes.
- Import discovery is single-active: a new subscription cancels and finishes the prior stream. A synchronous per-request termination token prevents a stream canceled before actor registration from launching an orphan scan. Parent-task cancellation preserves selected routes, while a provider-originated `CancellationError` is treated as a source failure and removes that source.
- Runtime connection generations and client identity checks guard every suspension in connect. Disconnect or a newer connect invalidates stale work, and stale cleanup disconnects only its own client without clearing newer state.
- USB and BLE use the same `BetaflightClient`, dataflash, CLI configuration, progress, payload, and temporary-directory ownership pipeline.
- Hardware validation with `SBADAPTER3_C571` reached Betaflight identity and a full 16 MiB FlashFS through SpeedyBee V2 (`ABF0`, write `ABF1`, notify `ABF2`). BLE uses Betaflight Huffman-compressed dataflash reads with a 400-byte output budget. A 256-byte budget can produce a valid zero-character compressed response when no complete 256-byte source block fits; 512-byte responses failed after initially transferring data. The 400-byte path ran for more than four minutes and decoded over 837 KiB without retries, timeouts, checksum failures, or disconnection, but throughput remained roughly 3.2 KiB/s. Uncompressed 4,096-byte responses produced checksum failures.
- Further BLE throughput optimization is deliberately deferred until the complete import vertical slice works end to end. The detailed benchmark, telemetry, timeout, adaptive-budget, progress-cadence, and SpeedyBee-specific investigation plan lives in `BACKLOG.md`; the 400-byte compressed path remains the stable baseline meanwhile.
- Assistant connection failures should be actionable when a typed cause is available and remain generic when it is not. In particular, a USB serial port already opened by another application should be presented as in-use rather than as an unreachable flight controller.
- `Delete Logs After Import` remains visible but disabled in the current scope.
- Imported Blackbox bytes remain byte-identical. Temporary files are retained until successful materialization or definitive cancellation.
- `FlightControllerImportPayload` carries the FC identity, capture time, ordered downloaded logs, optional configuration snapshot, file sizes, and SHA-256 hashes. Its actor-owned temporary directory is created by the package, can be transferred exactly once by the assistant, and is discarded explicitly and idempotently.
- App-side payload completion materializes a new package, uses native destination UI (`NSSavePanel` on macOS and SwiftUI `fileExporter` on iOS/iPadOS), persists, opens the document, and only then discards temporary files. Destination cancellation and failures before opening return the payload for retry. A cleanup failure is reported after the successfully opened document and does not repeat document creation.
