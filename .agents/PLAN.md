# Current Plan

Implement the Flight Controller Import Assistant on `feature/flight-controller-import`. Every numbered milestone ends in verification and one commit, followed by a mandatory review stop.

## Think Before Coding

- Keep `MSP` generic and independent of Betaflight, Blackbox, transports, documents, and UI.
- Log MSP/CLI communication metadata through `Logging` without recording payload or CLI contents.
- Keep Betaflight behavior and serial/BLE transports in `FlightController`.
- The assistant returns a file-backed `FlightControllerImportPayload`; it never decides whether to create or extend a document.
- The app-side materializer creates a new package now and exposes the same atomic append path for future imports into open documents.
- Preserve downloaded Blackbox bytes exactly. Support onboard FlashFS only; do not imply MSP SD-card file access.
- `Delete Logs After Import` toggle is wired to `MSP_DATAFLASH_ERASE`. Toggle (and log download) is only enabled when the blackbox device is `.flash`; otherwise both are forced off and a hint text explains the constraint. Erase runs after successful document materialization, guarded by a confirmation alert.
- Use no new external dependency without explicit approval.

## Simplicity First

- Assistant flow: Prepare → Device → Connect → Content → Import.
- macOS discovery combines USB serial and BLE devices; iOS/iPadOS shows BLE only.
- Connection validates MSP API version, `BTFL` variant, firmware, board, build, and FlashFS summary.
- Selected operations are log download and/or CLI configuration snapshot.
- Report real byte progress for FlashFS and indeterminate progress for CLI dump.
- Store temporary outputs under one managed import directory until successful materialization or final cancellation.
- Airframe format version 2 stores ordered FC import snapshots and content-addressed config files while reading version 1 unchanged.

## Surgical Changes

1. Add matching feature branches, pin `betaflight-configurator/` as a read-only reference, and update durable context.
2. Add the generic `MSP` package with v1/v2 frames, streaming decode, checksums, request coordination, timeout, cancellation, and CLI framing.
3. Add `FlightController` domain types, transport protocol, Betaflight client, and discovery abstractions.
4. Add the native SwiftUI assistant shell, captions, previews, step state, and mock discovery.
5. Add macOS IOKit/POSIX USB serial transport and real handshake/content discovery.
6. Add bounded, resumable file-backed FlashFS download with progress and cleanup.
7. Add CLI dump and validated `blackbox_*` settings reads/writes.
8. Add reusable payload types and explicit temporary-directory ownership.
9. Add append-capable package format version 2 and one atomic `AirframeImportMaterializer` mutation used by create and append.
10. Connect `StartView` to native destination selection, package creation, opening, and cleanup.
11. Add CoreBluetooth transport and known SpeedyBee/Nordic UART profiles.
12. Complete the shared BLE flow on macOS and real iOS/iPadOS devices.

Do not start a later item before the user approves the preceding commit. Do not add the open-document import UI yet.

## Goal-Driven Execution

- Each package milestone runs focused Swift Testing suites.
- App milestones build for macOS and iOS and add focused app/UI tests where platform behavior requires XCTest.
- Protocol tests cover fragmented/coalesced frames, checksums, malformed input, timeout, retry, and cancellation.
- Transport tests cover partial I/O, disconnect, reconnect, and BLE write chunking.
- Import tests cover logs-only, config-only, combined payloads, duplicate hashes, atomic append, version-1 compatibility, and temp cleanup.
- Hardware acceptance proves cable import on macOS and SpeedyBee Adapter 3 import on macOS and real iOS/iPadOS.
- A milestone is complete only when its behavior is verified, its diff is reviewed for scope, and its commit exists in the correct repository.
