# Active Tasks

Only approved near-term work and unresolved items belong here. Completed work belongs in Git; unapproved ideas belong in `BACKLOG.md`.

## Active: Regular-File Airframe Container

- Public-repository branch: `feature/airframe-container`; no commits or pushes without explicit approval.
- Container implementation committed in the public repository as `02477f1` (`Introduce regular-file Airframe containers`); it has not been pushed.
- Characterization fixtures freeze legacy v1/v2 semantics and zero-write read-only opening.
- A retained 1,001,472-byte real Betaflight legacy package fixture verifies byte-preserving read-only opening and first-mutation migration end to end.
- Automatic in-place legacy migration and dual-UTI opening have been removed. The normal document path registers and accepts only regular-file `.airframe` containers.
- The temporary File-menu command `Convert Legacy File…` selects a source package, asks for a destination through `NSSavePanel`, converts off the main actor, validates, preserves opaque files, and opens the result. Choosing the same URL atomically replaces the package only after validation; failure immediately before publication is regression-tested to preserve the source byte-for-byte.
- `Packages/AirframeContainer` provides physical format v1 primitives, streaming writer/reader, recovery, transactions, logical deletion, APFS-aware compaction, raw export, privacy-safe logging, and 45 passing tests.
- App integration includes a deterministic manifest, opaque-file retention, video-ready range reads, a revision-aware persistence actor, FC append durability, new-document conversion, close-time compaction, and explicit one-shot legacy conversion.
- Raw-log conversion finalization now replaces SwiftUI's package-shaped picker placeholder with a validated regular container through a same-volume coordinated replacement; the completed user-visible result is never the legacy package format.
- Raw-log and FC `Transferable` exports carry an explicit, non-empty suggested filename; regression coverage includes the folder-import save flow's user-facing `Kayoumini.airframe` name and empty-name fallbacks.
- macOS raw-log conversion uses a native Save panel that hides but retains the required `.airframe` suffix and disallows other file types. No export path repairs an extensionless result by writing to an unauthorized sibling URL.
- All macOS Save panels now share the same extension-enforcing factory, and preset/raw-log FileDocument exports receive extension-complete default names. Guard tests prevent unconfigured native Save panels from being added.
- FC creation now stages outside the sandboxed destination, validates before publication, and atomically publishes/replaces the exact Save-panel URL. Failures log their NSError domain/code and show the underlying localized reason while retaining imported data.
- Completed exhaustive I/O audit; permanent matrix is `DOCUMENT_IO_MATRIX.md`. BLOCK/HIGH remediations cover iOS close/replacement durability, Duplicate overwrite semantics, folder-scope lifetime, open regular-file validation, accurate legacy in-place wording, sandbox-safe package raw export, and artifact-level APF/BBL/BFL tests.
- Remaining release-only/manual evidence is tracked explicitly in the matrix: actual macOS/iOS picker/exporter UI and iCloud/third-party provider behavior cannot be proven by ordinary `/tmp` tests.
- The "legacy only in converter" isolation is implemented: generic directory/FileWrapper document APIs and native package write hooks are removed, normal Duplicate accepts regular containers only, raw-log and iOS FC exports use validated regular-container transfers, and a source guard confines legacy symbols to `LegacyAirframeConverter` plus dedicated compatibility tests.
- Validation after simplification: AirframeContainer 45/45; full macOS app suite 520/520 plus Swift Testing 2/2 and package-hosted tests 4/5 with one expected skip; macOS Release and generic iOS Simulator Release builds succeeded.
- Final automated gate on 2026-07-30: BlackboxCore 96 tests, BlackboxReader 224 tests, BlackboxAnalysis 178 tests, complete macOS app suite 521 tests, four UI smoke tests, macOS Release build, and generic iOS Simulator Release build all passed.
- Manual environment acceptance remains for real iCloud Drive/security-scoped providers, cross-volume fallback, large real-world document performance, and Instruments profiling because no representative `.airframe` corpus or configured external provider was available locally.

## Completed: Missing Graph Fields and Timeline Data Fallbacks

- Graph inspector rows now remain visible and disabled when their configured series is absent from the selected log; only a genuinely empty stored section shows the empty-state action.
- The shared Table/Graph timeline now resolves Motor Average %, mean Motor RPM, Setpoint Throttle, RC Command Throttle, then an empty time track, and stays scrub-capable for every usable main-frame time range.
- Fallback and unavailable states use localized info-symbol help plus accessibility text.
- Focused macOS app tests cover the field-row projection, every fallback source, RPM aggregation, and the sample-free loaded timeline.

## Completed: Map Picker Order and Document Title Stability

- Move Map to the rightmost position in the segmented mode picker, menu, and shortcut order: Spectrum is `⌘4`, Step Response is `⌘5`, and Map is `⌘6`.
- Keep macOS document windows titled with the opened document filename/source name instead of the selected log mode.
- Hide the Overview GPS card and disable/reject the Map segment and command when the current log has no usable GPS route.
- Focused `LogViewSelectionTests` passed on 2026-07-30.

## Completed: Shared Graph Event Chips in Map

- Extract the existing single Graph Event chip as reusable AirframeUI presentation.
- Share Event-to-chip content projection between Graph and Map.
- Replace Map's plain semantic detail line with the exact Graph chip.
- Generic Events retain only their title and metadata so the chip does not duplicate the title.
- AirframeUI's 118 tests, AirframeCaptions' 29 tests, and 16 focused app tests passed; complete macOS Release and iOS Simulator builds passed on 2026-07-30.

## Completed: GPS Map Event Context

- Flight Mode popovers identify which firmware-specific modes turned On or Off.
- Inflight Adjustment popovers identify the adjusted function and scaled value.
- Reuse centralized Event captions so Map, Table, and Graph terminology cannot drift.
- Fourteen focused app tests and 31 caption tests passed; complete macOS Release and iOS Simulator builds passed on 2026-07-29.

## Completed: GPS Map Annotation Information

- Add anchored native information popovers for Home and progressively revealed Events.
- Show coordinates plus available time/altitude without persistent labels, geocoding, or a detail sheet.
- Bound only the rendered route geometry while retaining exact current-position/event semantics.
- Route rendering is capped at 2,048 points while preserving endpoints and Event positions.
- Fourteen focused app tests and 29 caption tests passed; complete macOS Release and iOS Simulator builds passed on 2026-07-29.

## Completed: GPS Map Visual Refinement

- Anchor the heading cone exactly at the current-position dot and make it widen in the direction of travel.
- Force prompt MapKit route-prefix/position updates at recorded GPS-point boundaries without resetting user camera state.
- Remove visible annotation titles while retaining localized accessibility labels.
- Show every prepared event in the altitude timeline, independent of Current Position.
- Label the altitude timeline's horizontal grid lines.
- Follow-up refinement keeps the position/heading annotation identity stable to prevent blinking and omits negative grid values when all recorded relative altitudes are nonnegative.
- Focused app tests passed; complete macOS Release and iOS Simulator builds passed on 2026-07-29.

## Completed: GPS Overview and Native Flight Map

- Reader retains a bounded, time-associated GPS route plus first valid Home during the existing scan.
- Analysis exposes an immutable route, Home-relative altitude, normalized heading, event-to-route association, and binary-search cursor helpers.
- Overview presentation splits GPS metrics into a GPS card without changing the cached flight snapshot; the app hides that GPS card when the selected log has no usable GPS route.
- App integration adds `.map`, route availability/fallback, full-flight playback, per-segment settings, native MapKit rendering, progressive events, and altitude profile.
- Progressive Map annotations and profile event lines are pure functions of the shared current position, so backward scrubbing hides future events deterministically.
- BlackboxReader, BlackboxAnalysis, and AirframeCaptions package suites passed; focused app tests passed; complete macOS and iOS Simulator Release builds passed on 2026-07-29.
- Automated verification excludes network-delivered map tiles; final native-map appearance still benefits from an interactive smoke check with a representative GPS log.

## Completed: Semantic Flight Controller Status

- Framed CLI capture prefers structured `env` and falls back to tolerant `status`; legacy interactive firmware is skipped to avoid a disruptive reboot.
- Processor/clock, detected sensors, storage, and configuration state persist semantically with the import event; raw and volatile runtime values are not stored.
- The Import Assistant presents only the processor from semantic status, while Overview uses associated status for MCU and sensor model precedence.
- Direct, Wi-Fi, and Mass Storage payloads retain the same captured snapshot.
- No document-format bump; older documents decode without status.
- Post-import validation fixed an existential-dispatch regression that caused the first implementation to return `nil`; the explicit capture bridge is covered by the runtime integration test.
- Presentation feedback completed: Overview removes PID Profile, GPS Provider, and Motor RPM, selects one nonzero idle value, shows Maximum Altitude, and title-aligns the visible `More…` button.

## Completed: Overview Dashboard

- Reusable equal-width cards and technical key/value rows support optional card and row actions.
- Log File, Flight Controller, Blackbox, Configuration, Flight, and full-width Notes content are implemented.
- Blackbox settings, deterministic Recorded Data classification, searchable detail, and unknown-field retention are implemented.
- Versioned Overview snapshots persist in Airframe packages and are reused on open and raw-log conversion.
- The conversion sheet explains the retained analyzed-log-details benefit.
- Refinement completed: compact copy, Log Gaps placement, optional-row omission, equal row heights, sensor/MCU metadata, useful idle/PID configuration, and first/last-sample VBat.
- Final compact-card feedback completed: Flight omits Disarms; reusable headers center icon/title/action; persisted debug mode uses firmware-specific semantic names instead of raw numbers.
- Dashboard reorganization completed: Hardware and Power are separate cards; Flight owns GPS speed/distance metrics; Recovered Gaps is hidden and Log Gaps is presented as Gaps.
- Configuration semantics completed: protocol IDs display names, Dynamic Idle uses physical RPM, and Hardware/Configuration expose Gyro Sample Rate/PID Loop Rate.
- Swift package tests, focused cache tests, and complete iOS/macOS builds passed on 2026-07-28.

## Maintenance

- Keep `ReaderSeriesPresentation` and `AirframeCaptions` mappings synchronized when adding selectable field families or debug meanings. Add conversion and caption tests in the same change.
- Move consumer-facing `ReaderInfoReportBuilder` labels out of `BlackboxReader` without creating a `BlackboxReader` → `AirframeCaptions` dependency cycle. Prefer a semantic report model consumed by `AirframeCaptions`.

## Validation

- Validate the Map timeline source picker and its blue/green/teal/purple source colors on the MAYA Betaflight 4.5.2 package on both macOS and iPadOS.
- Validate Craft roll/pitch signs against the reference viewer on a representative real log.
- Validate Craft motor gauge colors against Graph colors while scrubbing.
- Expand automatic mixer-template checks beyond quad-X using representative bicopter, tricopter, Y4, V-tail, A-tail, Hex, Y6, X8, and octocopter logs.
- Continue compatibility coverage across representative Betaflight versions, multi-log files, GPS logs, and damaged/truncated logs.

## Flight Controller Import Assistant

- Execute the approved commit sequence on `feature/flight-controller-import`, stopping after every commit for review.
- Current review gate: the approved 12-commit implementation sequence is complete. Airframe `b3c8be7` is hardware-validated end to end on macOS and real iPadOS through SpeedyBee V2, including the Legacy-BLE log-only policy. Further BLE throughput optimization and continuous live discovery remain deferred in `BACKLOG.md`.
- Commit 1: feature branches, pinned Configurator reference, and durable project context.
- Commit 2: generic `MSP` package.
- Commit 3: `FlightController` domain and discovery.
- Commit 4: native assistant shell with mock discovery.
- Commit 5: macOS USB serial connection and Betaflight handshake.
- Commit 6: file-backed FlashFS download with progress, cancellation, retry, and cleanup.
- Commit 7: CLI dump and safe `blackbox_*` settings workflow.
- Commit 8: reusable `FlightControllerImportPayload` and temporary-directory ownership.
- Commit 9: append-capable Airframe format version 2 and materializer.
- Commit 10: new-document consumer from `StartView`.
- Commit 11: CoreBluetooth transport.
- Commit 12: BLE end-to-end integration on macOS and real iOS/iPadOS devices.

## Mass Storage Mode (MSC) Import

Approved plan: add a Mass Storage import method beside the existing Direct Mode. SD cards import only via MSC; onboard flash can use either. MSC activates via `MSP_SET_REBOOT` (code 68, mode 2), the link drops intentionally, the controller becomes a USB drive, the user picks the volume, logs are copied from `logs/LOG#####.BFL`, then materialized like Direct Mode. SD delete removes the log files plus `FREESPAC.E` (read-only bit cleared) so Betaflight reclaims space on the next power-up; flash delete over MSC is impossible (read-only volume) and uses a guided replug back to MSP. Implemented in verifiable steps.

- Step 1 (done, needs hardware verify): `BetaflightClient.rebootToMassStorage()` (tolerates the intentional link drop), mode-dependent `steps` array with `ImportMode`, `availableImportModes`, mode picker on the content screen, and the `prepareMassStorage` activation screen. SD forces MSC; flash defaults to Direct. Direct Mode unchanged. Package + app tests green; macOS build green. Verify on a real FC: connect, choose Mass Storage, activate, confirm the FC appears as a USB drive in Finder/Files.
  - Constraint learned from hardware: the interactive CLI config dump ends with `exit`, which reboots the controller, so it cannot directly precede the MSC reboot in one connection. Resolved by waiting for the fresh boot and reconnecting: `DefaultFlightControllerImportAssistantRuntime.reconnectAfterReboot(matching:timeout:)` (retries `makeTransport` + `connectAndIdentify` until the board identity matches, 30s timeout) runs after an interactive dump, then the MSC reboot fires on the reconnected client. New activation status `.reconnecting`. This helper is the reusable primitive for Step 5 (flash replug delete). Interactive dump over Bluetooth stays blocked (BLE reconnect-after-reboot is unreliable). Logging under category `flight-controller.import`.
- Step 2 (done, hardware-verified import): `MassStorageVolumeImporter` (nonisolated scan + off-main copy; scans root and `logs/`, prefers individual per-flight files, skips the combined `<fw>_ALL.BBL`, ignores hidden/PADDING.TXT). The volume picker is NOT a separate step: once MSC is active the "Select Drive" button + status appear below the activation confirmation on the `prepareMassStorage` screen (`selectVolumeSection`). `.fileImporter([.folder])`, security-scoped, scope retained for the later delete step. `state.selectVolume(url)` scans, copies into the prepared temp dir, builds `FlightControllerImportPayload`, then reuses the existing Done/completion/materializer path. New files must be registered in `App/Airframe.xcodeproj` via the `xcodeproj` gem (the FlightControllerImport group uses explicit refs, not a synchronized folder). App tests green (7 importer tests).
  - Bug fixed: files copied from a read-only FAT/exFAT/emfat volume carry the DOS read-only attribute as the immutable (uchg) flag, which `copyItem` propagates and which made `removeItem` fail with EPERM (the "temporary files could not be removed" dialog after save). `copyLogs` now clears `.immutable` and sets writable perms on each copy. Regression test `testCopiedLogsFromReadOnlyVolumeStayRemovable`.
  - Volume naming/pre-selection: the onboard-flash MSC volume label is always `BETAFLT` (firmware `emfat_init(&emfat, "BETAFLT", …)`), but an SD card keeps its own FAT label, so the name is only reliable for flash. `MassStorageVolumeLocator.detect()` reads mounted-volume metadata (sandbox-permitted; contents still need selection) to find a `BETAFLT` volume; the state polls for it after activation (mount delay). When found, the instruction names the drive and, on macOS, `NSOpenPanel.directoryURL` pre-navigates to it (falls back to `/Volumes`). iOS keeps `.fileImporter` (no pre-navigation). App is sandboxed (`ENABLE_APP_SANDBOX = YES`).
- Step 3 (done, hardware-verified): SD delete. `MassStorageDeletion.deleteSDCardLogs(logURLs:volumeRoot:)` removes the imported source files (captured as `importedVolumeLogURLs` at copy time) plus `FREESPAC.E` (matched case-insensitively; immutable/read-only cleared first; missing tolerated). Runs via `performMassStorageDeletionIfNeeded()` in the same `beforeOpen` closure as the erase path; guarded to `massStorage && sdCard && deletesLogsAfterImport`. Delete toggle enabled for SD MSC only (flash MSC volume is read-only). Tests: `MassStorageDeletionTests` (3) plus updated state gating.
  - UX: the deletion runs off the main actor (`Task.detached`) so the assistant renders progress instead of freezing; the Done button reads "Save & Delete Logs"; the progress screen shows distinct "Deleting Logs From the Card" and "Ejecting the Drive" phases and stays open until both finish. Bug fixed here: synchronous deletion on the main actor froze the UI.
  - Volume unmount: after delete (and after import-only), the state unmounts the volume with `FileManager.unmountVolume(at:options:[])` (macOS). Plain unmount, NOT `.allPartitionsAndEjectDisk`: a real SCSI eject makes Betaflight immediately re-present the mass storage device, causing macOS "not ejected properly" warnings. Plain unmount flushes the deletions (so the reclaim survives the power-cycle) and removes the volume without that side effect. Skipped when deletion failed (keeps the window open for retry). Security scope is re-acquired around the delete and released after unmount.
- Config-save + MSC intermittent failure (root-caused, fixed): with configuration import enabled the drive sometimes did not appear. Firmware (`betaflight/src/main/msp/msp.c:2428-2438`): `MSP_SET_REBOOT` to MSC replies `[rebootMode, readiness]`; when `mscCheckFilesystemReady()` is false it replies `[2, 0]` and does NOT reboot. Right after a CLI dump the SD/filesystem is briefly busy, so the reboot is silently declined. `rebootToMassStorage()` previously ignored the reply. Now it parses the readiness byte and retries up to 4 times (400ms apart, link stays alive on not-ready); if it stays not ready it throws `BetaflightClient.Error.massStorageNotReady`. The state maps that to a `MassStorageActivationStatus.notReady` with a "Try Again" button (`retryMassStorageActivation()`). Tests: `rebootToMassStorageSucceedsWhenFilesystemReady`, `rebootToMassStorageThrowsWhenFilesystemStaysNotReady`.
- Step 4 (done, needs hardware verify): connection-loss policy. `isConnectionLoss(_:)` classifies an error as a dropped established link (`BetaflightClient.Error.streamEnded/.streamFailed/.requestFailed(_, .disconnected)`, runtime `.notConnected`). When such an error escapes a runtime-driven operation (`prepareImport`, `prepareMassStorage`'s config dump), the state calls `abortToStart()`, which tears down connection/import/mass-storage state and returns the assistant to the `.prepare` page (stays open). The intentional MSC reboot drop never escapes (swallowed in `rebootToMassStorage`), and content-level failures (unsupported firmware, empty dataflash, `TestError`) still show their in-place errors. Volume-side failures during `selectVolume` are file errors, not link loss, so they keep the re-pick UI. Tests: `testConnectionLossDuringImportReturnsToFirstPage`, `testConnectionLossDuringMassStorageActivationReturnsToFirstPage`.
  - Idle monitoring was missing at first (unplugging on the connect/content screen did nothing until the next operation). Fixed with `startConnectionMonitor()`: while `monitorsConnection` (step `.connect`/`.content`, reachable, not busy, not activating MSC) it polls `runtime.isConnectionAlive()` every 500ms and aborts to the first page on loss. This causes no bus traffic — the transport ends its byte stream on unplug, which moves `BetaflightClient.state` out of `.connected`; the new `FlightControllerImportClient.isConnectionAlive()` just reads it. Test: `testUnpluggingWhileIdleOnContentReturnsToFirstPage` (with `LinkDropRuntime`).
  - Related bug: discovery is stopped when leaving the device step and `goBack()` never restarted it, so returning showed a stale device list (unplugged USB/BLE devices still listed). `goBack()` now clears `devices` and restarts discovery when returning to `.device`.
- Step 5 (done, hardware-verified): flash delete via guided replug. `awaitDeviceReturnAndErase(timeout:didReconnect:)` reuses `reconnectAfterReboot` (matches the board against `lastConnectedIdentity`, which now survives the MSC reboot) and then erases over MSP. State drives `FlashReplugStatus` (`awaitingReplug` → `erasing` → `succeeded`/`failed`); the volume is unmounted before the prompt so nothing is pulled while mounted. Save is disabled for the whole completion (`isCompletingPayload`); Cancel stays enabled during both replug phases and only stops waiting (`skipFlashReplugWait`), never invalidating the written document.
  - Two bugs found on hardware: (a) `willEraseAfterImport` was true for flash in MSC mode, so the direct MSP erase ran first, failed (the controller had left MSP), and its `runtime.disconnect()` cleared `lastConnectedRoute`, making the replug erase fail instantly with no prompt — it is now restricted to `importMode == .direct`; (b) copy progress was reported per file, so the bar stood still on large logs — `copyLogs` now streams 256 KB chunks and reports bytes (`VolumeSelectionStatus.copying(completedBytes:totalBytes:)`).
- Open-document import parity (fixed, hardware-verified): `Sidebar.appendPayloadIntoOpenDocument` ran `beforeOpen()` in a detached `Task` and returned `true` immediately. The assistant then left its completing state, dismissed, and `.onDisappear`'s `cancel()` wiped `selectedVolumeURL`, `importedVolumeLogURLs` and the connection before the deferred work ran — so SD deletion, unmount and the guided replug all no-opped and no progress was shown. This also explains the earlier unexplained log line with `hasVolume=false device=nil logCount=0`. It now awaits `beforeOpen()` like the new-document path. Contract covered by `testCleanupRunsWhenTheConsumerAwaitsBeforeOpen`, `testCleanupIsSkippedWhenTheConsumerReturnsBeforeBeforeOpenRuns`, `testCancelIsRefusedWhileTheCompletionIsRunning`. Note: those tests cover the state contract, not the Sidebar call site itself, which is only verified by reading the code and (pending) on hardware.
- Step 8 (done, visually verified): import method cards and removal of the Download Logs toggle.
  - `StartActionCard`/`StartActionCardStyle` moved out of `StartView.swift` into the shared `App/Airframe/App/ActionCard.swift` as `ActionCard`/`ActionCardStyle`. New knobs, all defaulting to today's behaviour so the start screen is untouched: `ActionCardSelection` (`.notSelectable` / `.selectable(isSelected:)`, drawn as accent fill `0.18` + accent border `0.65`, no checkmark), `minimumWidth` (platform default 220/140), `textFit` (`.uniformHeight` reserves two lines so a row shares one height; `.fitsContent` keeps the title on one line and lets the description grow). `accessibilityIdentifier` is now a parameter; the three start-screen call sites pass their previous identifiers. New files need registering via the `xcodeproj` gem — only `../Packages` is a synchronized group.
  - The assistant's `importMethodSection` renders two cards side by side in a plain `HStack`. `ViewThatFits` was tried first and always fell back to the stacked layout, because it measures each candidate's *ideal* width and the one-line ideal of the long description is far wider than the column. Equal card heights come from `maxHeight: .infinity` on the card's own content (`expandsToRowHeight`); applying it to the button from outside does nothing, since the style draws the background around the label.
  - `ImportOptions.downloadsLogs` and `setDownloadsLogs` are gone. In Direct mode the flag was initialised to exactly `canDownloadLogs` and could only be turned off, which forced `savesConfiguration = false` and blocked `canGoNext` — it could not produce a config-only import, and the materializer rejects log-less payloads for new documents anyway. Every direct-mode use became `canDownloadLogs`; `prepareImport` now guards `usedBytes > 0` unconditionally. Caption `app.fcImport.content.logs` removed from code and catalog.
- Step 6 (done): captions, microcopy, accessibility and previews.
  - Catalog coverage: 53 `app.fcImport.*` keys were referenced in code but missing from `Localizable.xcstrings`, so they silently fell back to their in-code English defaults and were invisible to translation. Not only the new mass storage keys — `erase.*`, `blackboxDevice.*` and `deleteLogs.confirm.*` had been missing since earlier work. All added. New guardrail `CaptionCatalogCoverageTests` scans the caption sources for literal keys and fails with the exact missing key list; interpolated keys are skipped. Verified it fails when a key is removed, so it is not a false-confidence test.
  - Stale copy fixed: the connect step showed "Log download and erase are only available … onboard flash" for SD cards, which stopped being true when mass storage import landed. The hint now keys off `availableImportModes.isEmpty` (`connectHint`) and reads "Set the flight controller's blackbox to onboard flash or an SD card to import logs. Current setting: %@." Both `optionsUnavailableNonFlash` variants and the dead `isBlackboxDeviceNonFlash` are gone.
  - A failed guided replug now shows `flashReplugFailedDetail` ("… You can erase them in Direct mode.") instead of the generic erase-failure text. Three genuinely unused captions removed (`selectDeviceTitle`, `massStorageCopyingProgress`, `deletedFromCard[.detail]`). Title case corrected to Apple style ("Deleting Logs from the Card").
  - Accessibility: the step capsules were fully hidden, leaving VoiceOver without progress context; the row now reports "Step X of Y" (`stepProgress`). Cards carry the `.isSelected` trait. Spinners keep their adjacent text as the spoken state.
  - Previews added for the import method on flash and SD card, and for the activated mass storage screen (drives the mock runtime via `.task`). The delete/replug progress phases need a written payload and are not preview-reachable without adding test hooks.

## SpeedyBee Adapter 3 Wi-Fi Import

Approved plan: add a third bulk-transfer method beside Direct and Mass Storage. The SpeedyBee Adapter 3 brings up its own open Wi-Fi AP (triggered over BLE), and Airframe downloads the raw `.BBL` over UDP. Protocol is in `SPEEDYBEE_REVERSE_ENGINEERING.md`, reference client in `tools/speedybee_wifi_probe.py`. Confirmed decisions: build macOS + iOS together (iOS Wi-Fi join needs the HotspotConfiguration entitlement and a configured Developer Team); keep Direct as an iOS fallback; always show the method cards but stack them vertically full-width and equal-height with a short property blurb each; use a macOS `airframe fc-wifi` CLI subcommand as the hardware harness for the transport steps. `availableImportModes` becomes an ordered, capability-aware list (`supportsWiFiDownload` detected via BLE name `SBADAPTER3_*`, confirmed by DEVICE_INFO `ADPT03116`). Implemented in verifiable steps.

- Step 1 (done): SpeedyBee protocol core in the FlightController package. Pure, transport-agnostic byte layer: control-channel protobuf codec + framing, WIFI_INFO/DEVICE_INFO blob parsers, LIST/STAT parse with the `^BTFL_\d+\.BBL$` filter, CRC-16/MODBUS, UDP reassembly (dedupe + truncate), and the shared typed `SpeedyBeeError` surface. 16 Swift Testing cases over the doc §13 vectors. Package tests and macOS app build green. No hardware needed. Airframe commit `aafc131`.
- Step 2 (done, hardware-verified): `SpeedyBeeWiFiClient` (TCP 4279 control, TCP 4278 MSP prepare, UDP 4281 data) + hidden `airframe fc-wifi list`/`download` subcommand, assuming the Mac is already joined. Uses raw Darwin sockets for all three channels so the UDP `SO_RCVBUF` can be 8 MiB (Network framework cannot size it). Verified end to end on a Flywoo F405S AIO / Betaflight 4.5.2 (onboard flash): downloaded `BTFL_001.BBL`, 391168 bytes, 192 packets CRC-valid, valid header. Airframe commit `8c97432`.
  - Key finding: the "prepare" command is `MSP_SET_REBOOT` (code 68) mode 2 (mass storage). Its `[rebootMode, readiness]` reply is optional. The PoC FC (SpeedyBee F435, BF 4.5.0) replied `[2,1]`; the Flywoo (BF 4.5.2) returns no reply yet still exposes the flash. Requiring the reply (the doc's original probe) produced a false `prepareTimeout`. The client now tolerates a missing reply, retries only while a present reply reports readiness 0 (then `massStorageNotReady`), and proves success by LIST populating. `SPEEDYBEE_REVERSE_ENGINEERING.md` §0/§5/§9/§12/§14.2 updated with this.
  - Note: `Packages/AirframeCLI/BTFL_001.BBL` is a local hardware-test download, left untracked (not committed).
- Step 3 (done, hardware-verified): BLE Wi-Fi activation over the ABF3/ABF4 control channel. `SpeedyBeeControlChannel` (actor) runs HELLO/SESSION/DEVICE_INFO/WIFI_INFO/WIFI_START over the internal `BluetoothAdapter`; `SpeedyBeeAdapter3WiFiImporter.activateWiFi()` owns its own `CoreBluetoothAdapter`, scans for the adapter, and returns SSID/MAC. A dedicated control `BluetoothProfile` (ABF0/ABF3/ABF4) is kept out of `known`/`candidates` so MSP resolution is unchanged. New `fc-wifi activate` CLI command. Verified on the Flywoo F405S: activate brings up the AP, and the full BLE-triggered path (activate → join → download) produced a valid `BTFL_001.BBL`. Airframe commit `25f2dd3`.
  - Hardware fixes: (a) hold BLE ~0.75 s after WIFI_START so the fire-and-forget write flushes before disconnect, or the AP never appears; (b) the download must run as one session (prepare once, poll LIST to wait for flash enumeration before STAT/SELECT, never re-prepare per file), and control replies must be matched by opcode because the channel buffers stale STATUS/LIST frames (a leftover LIST blob was being parsed as a STAT size). Recorded in `SPEEDYBEE_REVERSE_ENGINEERING.md` §14.1/§14.2.
  - Multi-file readiness: the client already supports it (`listLogs()` returns all `BTFL_NNN.BBL`; multiple `download(name:)` on one client share a single prepare). The download-all loop is Step 4; not yet hardware-tested since the test FC has one log.
- Step 4 (done, hardware-verified single-log): Wi-Fi join handling + full single-session import. `WiFiNetworkJoining` protocol with `CoreWLANWiFiJoining` (macOS; needs Location auth so it throws from a plain CLI), `HotspotConfigurationWiFiJoining` (iOS, compiled only, wired in Step 6), and `ManualWiFiJoining` (prompt + poll TCP reachability of 192.168.1.1:4279). `SpeedyBeeAdapter3WiFiImporter.importAllLogs(into:joining:progress:)` activates over BLE, joins, downloads every log with ONE client (single prepare, so the FC reboots to mass storage once), writes files, restores the previous network, reports a typed `SpeedyBeeImportProgress`. Package links CoreWLAN (macOS) / NetworkExtension (iOS). New `fc-wifi import` CLI (manual join by default, `--auto-join` for CoreWLAN). Verified on the Flywoo F405S: `fc-wifi import` produced `BTFL_001.BBL` (391168 bytes) end to end. Airframe commit `09e06a9`.
  - Still unexercised on hardware: the multi-file loop (test FC has one log). Code is single-prepare-safe for N files.
- Step 5 (done, verified in app on macOS for the detectable cases): assistant UX. Added `ImportMode.wifi`; Wi-Fi reuses the existing `.import` step (automatic like Direct, `prepareWiFi()` mirrors `prepareImport()`); method cards are now a vertical full-width equal-height stack rendered from the ordered `availableImportModes`; captions + progress strings added; mock runtime advertises the three device classes and drives a canned Wi-Fi progress; import progress screen shows activating/joining/downloading/rejoining. Runtime `prepareWiFi` default throws `wifiUnsupported` (real wiring is Step 6). Capability model uses two orthogonal signals on the state: `wifiCapable` (device exposes the ABF3/ABF4 control channel, carried as `Controller.offersWiFiDownload`; the `SBADAPTER3` name always counts) and `isExternalWiFiAdapter` (BLE name `SBADAPTER3_*`, meaning no host USB path).
  - Method availability matrix (canonical). Three independent rules: Direct offered iff blackbox is onboard flash (MSP cannot read SD); Mass Storage offered iff a host USB path is possible (i.e. NOT the external adapter; a cable over BT cannot be detected so it is offered whenever plausible); Wi-Fi offered iff the device is Wi-Fi-capable (ABF3/ABF4), only detectable over BLE. Ordering: USB puts Direct first; BLE puts Wi-Fi first (when present), then Mass Storage, then Direct last. Grid (star = default):

    | Connection | Device / capability | Storage | Direct | Mass Storage | Wi-Fi |
    |---|---|---|---|---|---|
    | USB (macOS) | any FC | Flash | yes (default) | yes | - |
    | USB (macOS) | any FC | SD | - | yes (default) | - |
    | Bluetooth | plain FC (no Wi-Fi) | Flash | yes | yes (default) | - |
    | Bluetooth | plain FC | SD | - | yes (default) | - |
    | Bluetooth | external SpeedyBee adapter | Flash | yes | - | yes (default) |
    | Bluetooth | external SpeedyBee adapter | SD | - | - | yes (default) |
    | Bluetooth | built-in-Wi-Fi FC | Flash | yes | yes | yes (default) |
    | Bluetooth | built-in-Wi-Fi FC | SD | - | yes | yes (default) |

  - Caveat: Mass Storage over Bluetooth cannot detect whether a USB cable is actually attached, so it is offered but may be unusable (the "powered by a powerbank, no cable to host" case). No current signal distinguishes this.
  - Hardware-verified by the user (macOS): adapter+SD = Wi-Fi only; adapter+flash = Wi-Fi+Direct; USB flash = Direct+MSC; BT plain FC = Direct+MSC (or MSC-first); BT+USB same FC = MSC; adapter with the same FC = Wi-Fi only. All correct.
- Step 6 (done, hardware-verified in the app on macOS): runtime wiring + entitlements + end-to-end. `DefaultFlightControllerImportAssistantRuntime.prepareWiFi` tears down the BLE MSP link, runs `SpeedyBeeAdapter3WiFiImporter.importAllLogs` with `ManualWiFiJoining` (user joins the SSID, reachability poll unblocks), builds the payload from the downloaded files. Entitlements: macOS `com.apple.security.network.client` AND `network.server` (the UDP receive `bind()` is a server operation; without it EPERM), iOS `NSLocalNetworkUsageDescription` in Info.plist. Wi-Fi progress shows byte counts like the other methods (packets x 2044). Verified in the app: all 7 logs (8.4 MB) into a saved document.
  - Transport hardening from this step's hardware debugging (all in `SpeedyBeeWiFiClient`, doc updated): STAT sizes are 2048-block-rounded, so the true packet count is a two-value window; completion = gap-free prefix >= minimum + SELECT completion ack (no more phantom-packet waits). Reburst only after the burst-finished ack (mid-burst re-SELECT wedges the adapter). Inter-file drains (3 s quiet when a leftover restream is possible, 0.3 s after a clean ack end, budget 60 s). Enumerate once per session. Opcode-matched control reads. Out-of-range seq guard. Progress throttled to 150 ms (per-packet callbacks drop packets). STATUS budget 45 s (session establishment takes 20 s+, official app too). Prepare retries only while readiness = 0.
  - Adapter insight (via its display): it is a buffering relay; it reads logs from the FC over the wire into ~3.2 MB RAM and streams from RAM at WiFi speed; larger files drop to FC-read speed at that fixed offset (transfer glyph on the display). Deterministic slow tails on big logs are adapter-inherent.
- Step 6b (done, hardware-verified on macOS): automatic Wi-Fi join. New `PlatformWiFiJoining` tries the platform-native join (CoreWLAN on macOS, `NEHotspotConfiguration` on iOS), then still waits for the adapter's control port to answer (association is not connectivity), and falls back to the manual prompt on any failure. `restore` runs only after an automatic join, because a manual join leaves the previous network's password unknown. `LocationAuthorization` requests When In Use authorization on the main actor (macOS 14+ gates CoreWLAN scanning behind Location Services); denial degrades to the manual path. Shared `WiFiReachability` helper. Entitlement `com.apple.security.personal-information.location` + `NSLocationWhenInUseUsageDescription`. New caption `wifi.manualJoin`; `wifi.joining` is now the automatic "Connecting to …" text, and `WiFiPreparationProgress` gained `awaitingManualJoin(ssid:)`.
  - Step 6c (code complete, blocked on the developer portal): the iOS `NEHotspotConfiguration` path is implemented and selected automatically, but `com.apple.developer.networking.HotspotConfiguration` could NOT be added: the team provisioning profile for `com.kumkju.airframe` does not include the Hotspot capability, and the iOS build fails to provision with it. The entitlement was reverted. Enable the Hotspot Configuration capability for that App ID in the Apple Developer portal, regenerate the profile, then re-add the entitlement. Until then iOS uses the manual-join fallback, which works.
    - Verified on a real iPhone: BLE Wi-Fi activation works on iOS (`SpeedyBee WiFi activation ssid=SBADAPTER3_C571 model=ADPT03116`), which had never been exercised on a device before. The join then fails as expected and falls back cleanly.
    - Diagnostic signature of the missing entitlement, worth recognizing: `Failed to send a 9 message to nehelper: Connection invalid` and `NEHotspotConfigurationHelper failed to communicate to helper server`, surfaced by NetworkExtension as the unspecific `internal error`. It is an entitlement problem, not a runtime bug.
    - Expectation for later: even with the entitlement iOS always shows its own confirmation dialog before joining, so one tap remains. In exchange `joinOnce` plus removing the configuration returns the device to the previous network by itself, which macOS cannot guarantee.
  - Still open, deferred: ABF3/ABF4 capability detection at connect for built-in-Wi-Fi FCs (currently only the external adapter is recognized, by name), reburst packet-loss root cause, and a "connecting to the adapter" progress state (all in `BACKLOG.md`).

## Product Decisions Needed

- Decide whether a future transformed/persisted index is justified only after profiling package open, seek, memory, and autosave costs.
- Decide the final project license before adding SPDX license identifiers.

## Current Constraints

- The reviewed Flight Controller Import Assistant and GPS Map implementations are approved; other product work remains planning-only unless separately requested.
- No new external dependency without explicit approval.
- Raw Betaflight logs remain byte-identical and read-only.
- Airframe document state belongs in package metadata; raw-log UI state remains external.
- Bookmarks are not part of document format version 1.
