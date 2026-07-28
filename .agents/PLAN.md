# Current Plan

Normalize the reusable Overview card header height.

## Think Before Coding

- The optional action currently raises only cards that contain it because its 44-point hit target becomes the HStack's intrinsic height.
- Preserve the accessible action target and Dynamic Type expansion.

## Simplicity First

- Give every card's primary header row the same 44-point minimum height.

## Surgical Changes

- Change only the shared header HStack; do not add invisible placeholder buttons or per-card offsets.

## Goal-Driven Execution

- Verify compilation and confirm that action and non-action cards share identical content start positions.

## Previous Overview Refinement Plan

Refine the Overview card headers and compact pilot-facing values.

## Think Before Coding

- Resolve Blackbox debug numbers through the firmware's semantic debug-mode catalog rather than presenting raw numeric configuration values.
- Keep removed rows in the domain snapshot when they may remain useful elsewhere; this change concerns compact Overview presentation.
- Fix header alignment once in the reusable card component so every card receives the same geometry.

## Simplicity First

- Omit Disarms from the Flight card.
- Present a known debug mode by name and retain an honest unknown fallback for future firmware values.
- Vertically center icon, title content, and optional `More…` button in one shared header row.

## Surgical Changes

- Change only the Flight card row composition, the reusable card header layout, debug-mode resolution, focused tests, and the Overview cache algorithm identity if derived output changes.
- Do not redesign card bodies, navigation, or recorded-data details.

## Goal-Driven Execution

- Delegate independent Reader and SwiftUI edits, integrate without overwriting existing uncommitted work, and verify focused package tests plus macOS/iOS builds.
- Confirm the supplied Betaflight 4.6 value `19` presents as `GYRO_RAW`, all known values resolve deterministically, and future unknown values remain understandable.

## Previous Overview Dashboard Plan

Implement the adaptive Overview dashboard with persistent derived data.

## Think Before Coding

- Reuse the existing one-pass Reader scan and immutable source hashes; never rescan solely for Overview presentation.
- Keep semantic Overview snapshots independent from localized UI strings and cache-envelope identity.
- Derive recorded Blackbox availability from frame definitions, not from configuration intent.
- Preserve raw logs as read-only; persist Overview snapshots and Notes only in writable Airframe documents.

## Simplicity First

- Use equal-width adaptive cards containing compact technical key/value tables.
- Keep explicit card-level `More…` actions separate from optional value-scoped row buttons.
- Show card structure while scan-backed values load.
- Implement Recorded Data and configuration-file details as auxiliary sheets, not new primary log modes.

## Surgical Changes

1. Add typed Reader Overview snapshots, Blackbox classification, and scan-backed pilot metrics.
2. Add bounded Betaflight `dump all` parsing and deterministic associated/older configuration selection.
3. Store versioned Overview cache envelopes in existing package index data.
4. Add reusable card, table, row, and action components.
5. Compose Log File, Flight Controller, Blackbox, Configuration, and Flight cards plus full-width Notes.
6. Add searchable Recorded Data detail and read-only configuration-file detail.
7. Transfer already calculated snapshots during raw-log conversion and explain the benefit in the conversion prompt.
8. Verify packages, document round trips, iOS/macOS builds, compact layouts, Dynamic Type, and accessibility.

## Goal-Driven Execution

- Run independent Reader, cache/config, UI, and captions work through agents with exclusive file ownership, then integrate centrally.
- Accept only typed, tested, bounded data paths; missing values remain unknown rather than guessed.
- Finish with green focused package tests, app tests, iOS/macOS builds, and durable `.agents/` updates.
- Add the future GPS flight map and Start Location action to the backlog without reserving speculative persisted fields.

## Completed Flight Controller Import Plan

The prior Flight Controller Import Assistant plan is retained below for historical context.

## Think Before Coding

- Keep `MSP` generic and independent of Betaflight, Blackbox, transports, documents, and UI.
- Log MSP/CLI communication metadata through `Logging` without recording payload or CLI contents.
- Keep Betaflight behavior and serial/BLE transports in `FlightController`.
- The assistant returns a file-backed `FlightControllerImportPayload`; it never decides whether to create or extend a document.
- The app-side materializer creates a new package now and exposes the same atomic append path for future imports into open documents.
- Preserve downloaded Blackbox bytes through the valid log segment and trim FlashFS tail bytes after a terminal log-end marker during materialization. Support onboard FlashFS only; do not imply MSP SD-card file access.
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
# Flight Controller Runtime Identity Capture

## Think Before Coding

- Capture runtime identity while Airframe already owns a live FC connection during import.
- Prefer the structured Betaflight `env` command and fall back to tolerant `status` parsing for older firmware.
- Keep stable identity/hardware facts separate from volatile import-time diagnostics and from configured state in `dump all`.
- Persist only a typed semantic snapshot; do not store the raw CLI response.

## Simplicity First

- Use one optional semantic snapshot shared by the import payload, document import record, assistant summary, and Overview precedence.
- Start with useful stable facts: firmware/build identity, target/board/manufacturer, exact MCU and clock, configuration state/size, detected hardware, and flash geometry.
- The assistant shows only concise general FC facts; sensor-chip detail remains in Overview.
- Unsupported or missing fields stay absent and never block log import.

## Surgical Changes

- Extend the existing CLI capture path rather than adding a second connection lifecycle.
- Add focused parsers for `env` and `status`, typed transport APIs, backward-compatible optional document fields, and narrow UI rows.
- Preserve current framed/interactive recovery behavior and all existing import modes.
- Increment Overview cache semantics when runtime identity begins taking precedence over inferred values.

## Goal-Driven Execution

- Verify structured parsing, fallback behavior, old-firmware absence, semantic Codable compatibility, payload/document round trips, assistant presentation, and Overview precedence.
- Run FlightController and format package tests, focused app tests, and complete iOS/macOS builds.
- Record stable protocol/version findings in `.agents/RESEARCH.md` and keep deferred diagnostic presentation in `.agents/BACKLOG.md`.
# Overview Information Hierarchy Refinement

## Think Before Coding

- Distinguish concrete detected GPS model names from configured providers; only the former belongs in the FC hardware row.
- Prefer one meaningful idle mode and remove rows that do not help a pilot scan the Overview.
- Keep persisted domain data intact when a value is merely removed from compact presentation.

## Simplicity First

- Assistant connected summary shows Board, Firmware, Processor, and Blackbox storage; Clock and Configuration State remain semantic data but are not displayed there.
- Configuration shows Dynamic Idle when nonzero, otherwise Motor Idle when nonzero; PID summary and GPS Provider are omitted.
- Flight shows Maximum Altitude only and omits Motor RPM.
- `More…` uses one native prominent card action aligned with the card title.

## Surgical Changes

- Change presentation and captions without removing reusable domain fields.
- Parse GPS runtime status into only concise module generations such as `M10`; unknown or provider-only values remain model-less.
- Bump the Overview algorithm version because cached GPS presentation semantics changed.

## Goal-Driven Execution

- Verify GPS parsing, idle selection, row omission, caption copy, button accessibility/alignment, and complete iOS/macOS compilation.
- Run FlightController, BlackboxReader, and AirframeCaptions tests plus focused app tests where applicable.
