# Active Tasks

Only approved near-term work and unresolved items belong here. Completed work belongs in Git; unapproved ideas belong in `BACKLOG.md`.

## Maintenance

- Keep `ReaderSeriesPresentation` and `AirframeCaptions` mappings synchronized when adding selectable field families or debug meanings. Add conversion and caption tests in the same change.
- Move consumer-facing `ReaderInfoReportBuilder` labels out of `BlackboxReader` without creating a `BlackboxReader` → `AirframeCaptions` dependency cycle. Prefer a semantic report model consumed by `AirframeCaptions`.

## Validation

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
- Step 4: connection-loss policy (`abortToStart`), excluding the intentional MSC drop.
- Step 5: flash delete via guided replug (`awaitDeviceReturnAndErase`), needs a flash FC to verify.
- Step 6: captions/microcopy polish, VoiceOver, previews.

## Product Decisions Needed

- Decide whether a future transformed/persisted index is justified only after profiling package open, seek, memory, and autosave costs.
- Decide the final project license before adding SPDX license identifiers.

## Current Constraints

- Implementation is approved only for the reviewed Flight Controller Import Assistant milestone; other product work remains planning-only.
- No new external dependency without explicit approval.
- Raw Betaflight logs remain byte-identical and read-only.
- Airframe document state belongs in package metadata; raw-log UI state remains external.
- Bookmarks are not part of document format version 1.
