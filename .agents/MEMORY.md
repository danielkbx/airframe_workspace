# Project Memory

- Close-time compaction is best-effort maintenance after all pending revisions are durable. A preparation/publication failure must discard its candidate, log the structural failure, preserve the authoritative container, and allow the document to close; only flush/save failures may veto close.
- Native document close logging must always emit start, flush completion, maintenance completion, or a privacy-safe structured error. Raw Swift enum/NSError ordinals such as `ContainerError error 13` are not acceptable user diagnostics.
- Automatic in-place legacy migration is abandoned. The app registers only the regular-file `.airframe` document type. A temporary explicit legacy converter lets the user select a package, converts and validates it without modifying the source, and then uses the native Save dialog so the user grants and chooses the destination.
- Legacy package decoding is isolated in `LegacyAirframeConverter.swift`. Normal document open, save, duplicate, raw-log conversion, and flight-controller creation accept or emit only regular container files; a source-guard test rejects legacy directory/FileWrapper APIs outside the converter and its dedicated compatibility tests.
- SwiftUI exports use a prebuilt, validated regular-container `Transferable`, avoiding package-shaped `FileDocument` placeholders on both macOS and iOS.
- A `FileRepresentation` used by SwiftUI's exporter must provide a non-empty `.suggestedFileName`; relying only on the transferred URL and the view's `defaultFilename` can make SwiftUI call `NSFileWrapper.setPreferredFilename("")` and raise an uncaught Objective-C exception. On the current CoreTransferable runtime, the per-item closure overload recursively resolves generic metadata and crashes with `EXC_BAD_ACCESS`, so `AirframeContainerTransfer` uses the constant overload while independently normalizing the actual temporary filename.
- Never derive a sibling destination by appending `.airframe` after a sandboxed Save operation: the user granted access only to the exact returned URL. macOS raw-log conversion therefore uses an `NSSavePanel` configured to own, hide, and require the `.airframe` extension, then publishes exactly to its URL. Other picker completions validate that the exact returned URL already has the required extension and otherwise fail without writing elsewhere.
- All native Save panels are constructed through `AirframeSavePanel`: one allowed content type, `allowsOtherFileTypes = false`, a hidden but immutable extension, and an extension-bearing default filename. A source guard forbids direct `NSSavePanel()` construction elsewhere. FileDocument exporters likewise receive explicit `.apf`, `.bbl`, or `.bfl` filenames.
- A save-panel grant does not authorize a container writer's private sibling staging file. FC new-document creation writes and validates in Foundation's same-volume item-replacement directory, then coordinates publication exactly onto the granted destination; confirmed existing destinations are atomically replaced. The payload remains retryable until publication and open both succeed.
- The authoritative cross-platform inventory and release gates for all file boundaries live in `DOCUMENT_IO_MATRIX.md`; codec/unit success is never treated as proof of picker, sandbox, provider, or lifecycle behavior.
- iOS close must veto closure on durable flush failure, retain its scope and pending revision, and support retry. Close-time compaction remains best-effort only after the flush succeeds; workspace replacement waits for the previous UIDocument close result.
- Duplicate honors Save-panel replacement: it stages and validates a same-volume candidate, atomically publishes to the exact destination, and never deletes a valid published destination merely because presenting/opening its new window fails.
- Folder-open security scope remains active until NSDocumentController finishes opening the selected child log; reading the folder into memory alone did not authorize a later child-URL open.
- The macOS File menu must not expose AppKit Save, Save As, Revert, or Browse Versions. Airframe persists internal changes explicitly; invoking AppKit's save pipeline can produce conflict/version dialogs and is unsupported. `DocumentFileMenuPolicy` removes these native actions even if SwiftUI/AppKit re-adds them later.
- Explicit legacy conversion builds its candidate in Foundation's same-volume item-replacement directory, validates it there, then publishes it through `NSFileCoordinator` to the exact Save-panel-authorized URL. The source and destination security scopes remain active for the complete operation; the container writer must not create an unauthorized sibling beside the destination.
- The explicit converter permits the Save destination to equal the selected legacy source URL. It validates the complete candidate first, then atomically replaces the directory package with the regular file; other pre-existing destinations remain protected from overwrite.
- The temporary conversion command is titled `Convert Legacy File…`. Converter tests inject failure immediately before publication and require byte-identical source preservation for in-place conversion, no destination for separate conversion, plus explicit v1/v2, real-fixture, opaque-file, collision, invalid-source, native-open, close, and reopen coverage.
- `Convert Legacy File…` runs a read-only, off-main-actor source preflight immediately after the source picker and before presenting `NSSavePanel`. Unreadable packages fail before the user is asked for a destination; the source security scope remains active through preflight and conversion.
- Raw Betaflight log “Save as Airframe Document” may receive a temporary directory placeholder from SwiftUI `FileDocument`, but the finalizer never treats it as the saved format: it builds and validates a regular container in a same-volume replacement directory and atomically replaces the placeholder before opening or closing the source log.
- macOS uses `AirframeDocumentController` to classify regular `.airframe` files explicitly. This avoids stale Launch Services caches from pre-container builds; directory packages are deliberately not classified as normal documents.
- The regular container UTI is `com.kumkju.airframe.container-document`; the logical metadata format identifier remains `com.kumkju.airframe.document`. Reusing the former package UTI for a regular file is unsafe because Launch Services retains its original conformance.
- macOS Open panels expose exactly `.airframe`, `.bbl`, and `.bfl` through an extension filter. Their delegate disables `.airframe` directories while retaining normal folder navigation, so cached legacy-package UTIs cannot hide regular containers or enable old packages.

This file stores durable decisions and constraints. It intentionally omits implementation diaries, commit lists, and test transcripts.

## Airframe Regular-File Container

- `.airframe` moves from a directory package to an uncompressed append-only regular file optimized for streaming and random range reads.
- Physical `containerVersion = 1` is independent from logical metadata `formatVersion = 2`.
- Autosaves append immutable blobs and a complete snapshot commit; full compaction never runs on the autosave path.
- APFS `clonefile` is the tail-compaction fast path; bounded streaming is the portable and cross-volume fallback.
- Legacy packages are not opened as normal documents. They remain byte-unchanged and can only be converted through the explicit migration workflow.
- Duplicate-only FC imports are no-ops. Destructive source cleanup starts only after a durable flush.
- Unknown unreferenced legacy regular files survive migration as opaque blobs and remain live through later saves.
- Raw export writes primary payloads and `metadata.json`, excluding derived caches.
- Container logging never includes payloads, metadata JSON, notes, names, paths, hashes, configuration text, or device identifiers.
- Document payload limits are symmetric: writes reject payloads above 1 GiB (`AirframeContainerCodec.maximumPayloadByteCount`), and reads use `documentPayloadLimits` with the same 1 GiB `maximumReadLength`. The package default of 64 MiB must never be used for document-owned payloads; asymmetric limits made saved logs unopenable.
- Manifest-to-blob matching claims identical `(kind, byteCount, sha256)` payloads greedily via bucketed lookup (`matchBlobs`); duplicate content at several paths is valid, not ambiguous.
- Unknown blob kinds are read tolerantly: not materialized, retained verbatim through saves. Only document-owned kinds (metadata, log, configuration, index) are validated strictly. Decided before any tester files existed.
- `ContainerStore` holds an exclusive advisory `flock` for its lifetime; a second writer fails typed with `containerInUse`. The lock is re-acquired after compaction replaces the inode and released deterministically in `prepareForClose` — relying on actor `deinit` for release caused reopen failures.
- Locator publication and commit-data syncs use `F_FULLFSYNC` on Darwin (fsync fallback logged). Duplicate locator sequences no longer abort open; they degrade to `LocatorIssue`s and the bounded footer recovery scan still runs. `recoveryWasUsed` is logged as a warning at every open site.
- Mid-session compaction triggers after a commit when reclaimable bytes exceed 25% of file size and 10 MiB (`.tail` unless a deletion occurred); close keeps `.full`. Thresholds are internal-injectable for tests.
- Foundation's JSONDecoder caps nesting at ~512 levels (`DecodingError.dataCorrupted`), so `JSONValue`'s recursive decoding cannot stack-overflow on hostile container metadata; `JSONValueNestingTests` documents this. No depth limit needed.
- Autosave failures surface through `workspace.saveError` in a `DocumentView` banner (`SaveFailureBanner`, retry via `retrySilentSave()`); iOS close-flush failures keep the error pending on the controller. Silent-save state must never be log-only.

## Product

- Name: Airframe.
- Subtitle: A Blackbox Log Analyzer.
- Native Swift Universal app for iOS and macOS.
- Swift-native parser and model; no WebView wrapper.
- App Store distribution is optional.
- Project language is English for code, documentation, comments, commits, and artifacts.
- Build an independent implementation. Reference upstream behavior and formats, but do not translate source structure or implementation text.
- GPL-3.0 is acceptable if required, but the final license is not chosen.
- The primary log modes are Overview, Table, Graph, Spectrum, Step Response, and Map (`⌘1` through `⌘6` in that same order).
- The Map mode is the rightmost item in the segmented mode picker, menu, and numeric command shortcuts.
- macOS document windows leave the window title and File Proxy entirely to `NSDocument`/AppKit; no document content view may set a navigation or window title. The navigation subtitle is always exactly the effective name of the selected log. Log and mode changes must never alter the window title.
- The Overview GPS card is shown only when the current log has a usable GPS route: at least two time-associated, monotonic, valid, distinct coordinates. Logs without that route also have the Map segment and command disabled.
- The Overview GPS card is visible when the snapshot has at least one GPS fact (speed, distance, start coordinate, or satellites). Maximum Altitude appears in that visible GPS card; otherwise an available altitude appears in Flight. Altitude alone does not make the GPS card visible, and the row is omitted when no altitude exists.
- Map playback is chronological and reversible: route and Map-event visibility are derived solely from the shared current position, while Home is contextual and visible independently. The altitude timeline always shows every prepared event when Events is enabled.
- Map timeline sources are `GPS Altitude` (default), `Barometer Altitude`, `GPS Speed`, and `Distance from Home`. Their stable colors are blue, green, teal, and purple. The smallest compact picker belongs on the right side of the Map timeline toolbar; unavailable sources remain visible but disabled.
- GPS relative altitude uses GPS Home altitude when present and otherwise normalizes against the first valid retained GPS altitude. A usable route remains scrubbable even when no value source has enough samples.
- Map Event information reuses the actual Graph marker-chip renderer and shared Event-to-chip projection: Flight Mode changes show firmware-specific On/Off state segments, and Inflight Adjustments show the resolved function and scaled value. Generic Events do not repeat their title as a redundant chip.

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
- Terminology: the product term is capitalized "Blackbox" in every sentence position; unfiltered gyro signals are labeled "Gyro Unfiltered" (user decision 2026-07-29); PID term labels are hyphenated ("D-Term", "P-Term", "F-Term"); the spectrum window is the "Hann window"; the adjustment event family is spelled "Inflight adjustment".
- Overview Maximum Throttle derives percent from `setpoint[3]` (0...1000, /10) or as fallback `rcCommand[3]` (µs, (v-1000)/10); throttle and altitude extrema never pool multiple source fields. Reader-visible Overview calculation changes must bump `overviewCacheAlgorithmVersion`.

## Documents

- The app registers raw `.bbl` and `.bfl` files plus Airframe package documents. `.txt` and `.log` are not system-wide document types.
- Raw logs are read-only and never modified.
- `AirframeWorkspaceDocument` is the shared model for raw logs and `.airframe` packages.
- Package format version 2 contains `metadata.json`, source payloads stored under SHA-256-derived paths, ordered flight-controller import snapshots, and content-addressed CLI configurations under `flight-controller/config/<sha256>.txt`.
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
- Raw-log conversion benefits emphasize retained analysis setup, imported Betaflight configuration access, and keeping multiple logs together; avoid duplicating "analyzed details" and "faster reopen" as separate claims.
- Package sidebars flatten all source segments into one `Logs` section. Raw sidebars preserve file/log/reference hierarchy.
- Package source names may be customized per segment without changing bytes, hashes, parser titles, or original filenames.
- Effective package names are used consistently in navigation, Graph/Spectrum, and Step Response.
- Logs carry a conservative three-state quality classification (`nominal`, `warning`, `defective`) derived from Reader scan facts. Defective logs remain openable; the app marks them in the Sidebar and explains the status in Overview/Summary instead of blocking analysis views.
- Source removal is context-menu-only. Raw removal detaches without deleting the original file; package deletion removes embedded bytes and all contained logs from the document.

## UI Architecture

- `DocumentHomeView` owns document composition and the stable `NavigationSplitView`.
- The log Overview is an adaptive dashboard of equal-width technical cards in this order: Log, Checks, Flight, Power, Flight Controller, Hardware, Blackbox, and Configuration, followed by a full-width Notes editor for writable Airframe documents. Cards stretch to the tallest peer in each adaptive row.
- Overview cards use compact key/value tables. Cards may expose an explicit `More…` detail action and individual rows may expose explicit value-scoped action buttons; neither cards nor rows are implicitly tappable.
- Overview data cards are omitted once loading completes when none of their displayed rows has a value; a title or `More…` action alone does not count as content. Loading cards may remain visible while data resolves, and the empty Notes editor remains visible so users can create the first note.
- Overview-derived data is versioned and persisted inside Airframe documents so immutable logs do not need their Overview recalculated on every open. Raw logs keep calculated Overview data in memory only.
- Loaded Overview cards omit unavailable rows. Hardware labels stay conservative: sensor models require explicit header/config evidence, gyro reuses an accelerometer model only for known combined IMUs, and MCU family is inferred only from recognized STM32 family tokens.
- FC imports capture an optional semantic runtime status on framed-CLI firmware: `env` first, `status` fallback. It persists processor/clock, detected sensors, storage, and configuration state with the import event; raw CLI and volatile runtime diagnostics are never stored. Legacy interactive CLI is skipped because exiting would reboot and disrupt the live import.
- Associated semantic FC status takes precedence over inferred MCU/sensor labels in Overview and participates in the Overview cache input identity. The Import Assistant shows the processor but intentionally omits clock, configuration state, and sensor chips.
- Overview GPS hardware displays only a concrete concise module generation such as `M10`; configured providers and connection prose are not hardware model names. The compact Configuration card shows Dynamic Idle when nonzero, otherwise Motor Idle when nonzero.
- The compact Flight card omits Disarms. Every card header vertically centers its icon, title, and optional `More…` action in one shared row.
- Hardware owns Board and detected sensor/device models; Flight Controller retains identity, firmware, MCU, and UID. Power owns start/end voltage, consumed capacity, and current summaries.
- Hardware presents Gyro Sample Rate from Blackbox `looptime`; Configuration presents PID Loop Rate from `looptime × pid_process_denom`. These are runtime rates for the immutable logged flight, not observed Blackbox frame rates.
- Blackbox presents the effective Logging Rate resolved from gyro rate, `pid_process_denom`, `P interval`, and observed main-frame rate. The compact Overview normalizes integer-`looptime` artifacts to a nearby 25 Hz nominal value (for example `801.2 → 800`) and derives its displayed Nyquist Limit from that value. Nyquist status is green at `>= 800 Hz`, yellow at `500..<800 Hz`, and red below `500 Hz`; Spectrum and Overview share the same Reader-owned rate resolver while analysis retains the unsimplified rate.
- Overview configuration values are semantic: numeric motor/receiver protocol IDs resolve against Betaflight firmware enums, and Dynamic Idle persists physical RPM after converting the encoded hundreds-of-RPM setting.
- Flight GPS metrics include GPS-derived date/time from `GPS_home_epoch`, falling back to a valid `Log start datetime` header because `GPS_time` is only GPS milliseconds-of-week and cannot identify the calendar week by itself. They also include maximum and arithmetic-mean recorded speed, maximum great-circle displacement from the first valid GPS coordinate, and total great-circle distance across successive valid coordinates. They are aggregated during the existing one-pass scan and omitted without valid evidence.
- Blackbox debug-mode numbers are resolved against the Betaflight-version-specific enum order before they enter the persisted Overview snapshot; unknown future numbers display honestly as `Unknown (n)`.
- The Blackbox card distinguishes configured logging settings from fields actually recorded in frame definitions. Its Recorded Data detail preserves recognized and unknown fields.
- Searchable iOS sheets should stay close to system conventions with `NavigationStack`, `.navigationTitle`, `.searchable`, and toolbar actions. macOS sheets may use compact custom title-plus-search chrome when SwiftUI's navigation/search chrome creates excessive vertical spacing or misaligned headers.
- The sidebar is contextual navigation; the selected log's data belongs in the detail area.
- Current views are Overview, Table, Graph, Map, Spectrum, and Step Response.
- Step Response draws no per-trace text inside the graph. Per-axis P/I/D/F, accepted-window count, normalized peak, and response time live in that order in the inspector's aligned log table; its localized column headers explain their semantics through help and accessibility text.
- Step Response header help cells explicitly participate in hover tracking because framed `Text` alone does not reliably expose `.help` inside a macOS grouped `Form`.
- Graph field rows and Step Response log rows use full-width continuous hover regions to reduce trace-highlight interruptions while the pointer crosses internal whitespace.
- Graph inspector sections preserve every configured field row across logs. Fields absent from the selected log remain visible in their configured order and color, are disabled, and explain their unavailable status through an info symbol, help, and accessibility text. A graph section is empty only when its stored field-ID list is empty.
- Table and Graph share one timeline position/range and one playback transport. Future video must synchronize to this master transport.
- The shared Table/Graph timeline remains scrub-capable whenever the log has a usable main-frame time range, even without a plottable value series. Its deterministic plot-source fallback order is Motor Average %, mean Motor RPM normalized to the compact plot, Setpoint Throttle, RC Command Throttle, then an empty time track. Every fallback exposes an info-symbol explanation; the empty track retains cursor, ranges, markers, gaps, and accessibility adjustment.
- The Graph Craft preview shows one primary flight mode at the shared cursor: Failsafe, GPS Rescue, Autopilot, Turtle, Pos + Alt Hold, Position Hold, Altitude Hold, Angle, Horizon, Air, Acro, or Unknown. Air is only the Acro alternative; missing, truncated, or unverifiable evidence is Unknown and is never guessed.
- The Graph Craft preview keeps its attitude timeline decimated to 10 ms, but resolves motor gauges from the same full main frame at or before the shared cursor as the inspector readout. The decimated motor values are only a temporary fallback while the bounded cursor query completes.
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
- Complete configuration snapshots require `dump all`; `diff all` is not accepted because effective values would depend on exact firmware defaults. Interactive `dump all` remains supported over USB. Legacy Betaflight over BLE keeps log import available but disables configuration capture with an explanatory USB-or-upgrade hint.
- The complete legacy-BLE log-only import was hardware-validated with Betaflight 4.5.2 and SpeedyBee V2: discovery, handshake, content selection, compressed FlashFS transfer including the final partial source block, payload completion, and document consumption all succeeded.
- The same complete BLE log-only flow was validated on a physical iPad Pro running iPadOS 26.5. Commit 12 and the approved Flight Controller Import Assistant vertical slice are complete as of Airframe `b3c8be7`.
- MSP and CLI logs contain only lifecycle, command/frame metadata, byte counts, retries, and failures. Configuration contents, payload bytes, destination paths, and device identifiers are never logged.
- Production discovery must never inject mock devices. Preview mocks are compiled only in Debug.
- Serial transports can only be created from a currently discovered provider-owned device mapping; the app does not accept user-provided device paths.
- BLE discovery scans without a CoreBluetooth service filter because SpeedyBee Adapter 3 may omit service UUIDs and a usable name from advertisements. It publishes every discovered BLE peripheral in replacement snapshots keyed by opaque CoreBluetooth UUIDs with structured RSSI signal strength; support validation is deferred until after connection.
- BLE mappings carry ordered profile candidates. Advertised matches lead, followed by deterministic SpeedyBee, CC2541, HM-10, Nordic UART, DroneBridge, and HC-05 fallbacks matching the pinned Configurator. After connecting, CoreBluetooth discovers all primary services, resolves the actual known candidate, and only then discovers that profile's characteristics; unsupported peripherals fail with `serviceUnavailable` and disconnect.
- BLE service resolution normalizes 16-bit, 32-bit, and full 128-bit Bluetooth UUID forms. CoreBluetooth reports the hardware-validated SpeedyBee V2 service as short `ABF0`, while the profile registry stores its full base UUID.
- BLE devices carry an advisory `isLikelyFlightController` hint without affecting discovery eligibility. Known advertised profiles, normalized `SpeedyBee`/`SBADAPTER…` names, and common FC MCU prefixes such as F405, F722, H743, and G474 are suggested; USB is always suggested.
- The import assistant defaults to suggested devices when any exist and offers `Show All Bluetooth Devices` when other BLE devices are hidden. Showing all never restarts discovery; hiding all again moves a hidden selection to the preferred visible USB or strongest suggested BLE device.
- Flight Controller Import Assistant screens use non-duplicated text roles: headings explain the stage, body rows give current action or guidance, and progress labels carry numeric progress. Byte progress must use numeric `0` output, never nonnumeric formatter words such as `Zero`. Wi-Fi log download progress is split into aggregate byte progress across all selected files above the progress bar, `Log file X of Y…` below it, and an optional patience hint row while transfer is active.
- During Wi-Fi import, emit and show the rejoining/finalizing state before attempting to restore the previous Wi-Fi network. Platform Wi-Fi permission/confirmation dialogs should appear over a "download complete / reconnecting" screen, not over "Downloading Logs".
- The device page remains live while visible. USB changes are polled every 500 ms. BLE advertisements refresh a queue-confined visibility registry; peripherals that stop advertising expire after four seconds with one-second sweeps. A disappearing selection moves deterministically to the preferred remaining USB device or strongest suggested BLE device. USB attach/detach, BLE disappearance/reappearance, and selection fallback are hardware-validated on macOS.
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
- `Delete Logs After Import` is implemented via `MSP_DATAFLASH_ERASE` followed by a poll on `MSP_DATAFLASH_SUMMARY.ready` (500 ms cadence, tolerant to transient MSP timeouts, hard timeout 120 s). The toggle and log-download toggle are only enabled when the FC's blackbox device is `.flash` (checked via `MSP_BLACKBOX_CONFIG`, MSP 80). A confirmation alert precedes the destructive import path. Erase runs after successful document materialization; erase failures surface as a warning without invalidating the imported document.
- Imported Blackbox logs preserve source bytes through the Reader-discovered log segment end. FlashFS/source tail bytes after a valid terminal `E 0xFF "End of log" 0x00` marker are trimmed during materialization and package hashes are computed from the trimmed payload. Temporary files are retained until successful materialization or definitive cancellation.
- `FlightControllerImportPayload` carries the FC identity, capture time, ordered downloaded logs, optional configuration snapshot, file sizes, and SHA-256 hashes. Its actor-owned temporary directory is created by the package, can be transferred exactly once by the assistant, and is discarded explicitly and idempotently.
- App-side payload completion materializes a new package, uses native destination UI (`NSSavePanel` on macOS and SwiftUI `fileExporter` on iOS/iPadOS), persists, opens the document, and only then discards temporary files. Destination cancellation and failures before opening return the payload for retry. A cleanup failure is reported after the successfully opened document and does not repeat document creation.
- The SpeedyBee Adapter 3 also exposes a WiFi mode (open AP `SBADAPTER3_*`, gateway `192.168.1.1`) that lists and downloads blackbox logs far faster than BLE (~150 KiB/s). Its proprietary protocol is fully reverse-engineered, documented in `SPEEDYBEE_REVERSE_ENGINEERING.md`, and independently reimplemented and verified end to end by `tools/speedybee_wifi_probe.py` (downloaded a complete, CRC-valid BTFL_001.BBL). Full flow, both transports understood: (a) BLE — the same GATT service `ABF0` used by classic MSP now also carries a second control channel on `ABF3` (write) and `ABF4` (notify) that speaks byte-for-byte the same protobuf-style protocol as TCP 4279; op `0x17` returns SSID+MAC of the AP, op `0x18` fires the AP up (no BLE reply expected). (b) WiFi — TCP 4279 control channel (HELLO/SESSION/DEVICE_INFO, STATUS polled until bare ack while re-sending `"SPEEDYBEE\0"` to UDP 4281 to register the receive port), MSP "prepare" `$M< cmd 0x44 payload 0x02` on TCP 4278 (required before LIST populates), LIST/STAT/SELECT, and a UDP 4281 bulk stream of 2048-byte packets (u16 LE seq + u16 LE CRC-16/MODBUS + 2044 data). Loss recovery is done by re-issuing SELECT (bare re-trigger is ignored). No open questions remain for the log-download workflow.
- `LogViewCommandBroker` must ignore window notifications from windows that cannot become main. AppKit draws every open menu in an `NSPopupMenuWindow` that posts `didResignKey`/`willClose` while the pointer moves over the items; treating those as document-window changes bumps `revision`, makes SwiftUI re-render the commands, and its menu bridge then replaces the whole File submenu, dropping the AppKit items installed by `DocumentFileMenuPolicy` until the next run loop turn restores them. That race was the visible File-menu flicker (fixed 2026-07-31).
- SwiftUI owns the macOS File menu through its own `AppKitMainMenuItem` delegate and rebuilds the complete submenu on every command re-render. Anything injected there by AppKit is transient by construction, so the number of SwiftUI command re-renders is the real budget. Do not "fix" this by deferring menu mutations while a menu is tracking: after a SwiftUI rebuild the menu would stay reduced to the SwiftUI items for the rest of the menu session.
- SwiftUI `Map`'s `MapPolyline` cannot track playback (proven 2026-07-31, not fixed; see BACKLOG "Flight map path lags"). Two failure modes were verified in the app: (1) with a stable structural identity, `MapPolyline` never picks up changed coordinates — the overlay stays stale until something forces a rebuild (e.g. pausing playback); (2) forcing a new identity per change (the original `ForEach([index], id: \.self)` workaround, and equally a chunked variant with a small identity-churned tail) makes the visible overlay lag many seconds behind. Instrumentation ruled out the app side completely: body and MapContent builder ran ~20x/s with the correct, advancing point index and chunk counts while the rendered line stood still. The bottleneck is MapKit's SwiftUI polyline commit/rasterization pipeline under a continuous update stream. Decision: do not iterate further inside SwiftUI `Map`; the accepted future fix is an `MKMapView` representable (a Canvas overlay above the map was rejected because the path must render below the event/home annotations). Annotations (`Annotation` with SwiftUI content) update smoothly at the same rate — only polyline overlays are affected.
