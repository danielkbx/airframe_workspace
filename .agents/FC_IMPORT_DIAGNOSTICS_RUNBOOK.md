# Flight Controller Import Diagnostics Runbook

- Status: mandatory operational context for FC import diagnostics
- Last reviewed: 2026-08-07
- Report schema: `FlightControllerDiagnosticsSnapshot.schemaVersion == 1`
- Related implementation: `Airframe/Packages/FlightController/Sources/FlightController/FlightControllerDiagnostics.swift`
- Related evidence: `../knowledge/FLIGHT_CONTROLLER_CONNECTIVITY.md`

## When To Use This Document

Read this document before analyzing any Airframe Flight Controller Diagnostics attachment or any report copied from that attachment. Also read `../knowledge/FLIGHT_CONTROLLER_CONNECTIVITY.md` when the failure concerns a specific BLE profile, FC, firmware generation, or SpeedyBee behavior.

The diagnostic goal is to identify the last proven successful layer and the first failed transition. Do not jump from a terminal error to a hardware conclusion when the preceding transport and protocol evidence can localize the failure more narrowly.

## Why The Report Has This Shape

The import crosses several independent layers:

```text
Assistant choice
    ↓
Discovery and route ownership
    ↓
Serial or CoreBluetooth connection
    ↓
BLE service/characteristic/profile resolution
    ↓
MSP framing and request coordination
    ↓
Betaflight identity and capability reads
    ↓
Direct, Wi-Fi, or Mass Storage import orchestration
    ↓
Transfer completion and Blackbox readability validation
```

A single terminal message such as `timeout`, `disconnected`, or `noLogs` is therefore insufficient. The report records privacy-safe breadcrumbs at every boundary so analysis can distinguish discovery, route selection, link setup, framing, firmware response, transfer, and post-transfer validation failures.

The design follows these rules:

1. **One session, one recorder.** The assistant creates one recorder and injects it into discovery, transports, MSP, Betaflight, and app orchestration. Timestamps are comparable across all layers.
2. **Metadata, never contents.** Counts, UUIDs, command numbers, timings, capabilities, states, and safe error codes are useful. Blackbox bytes, configuration text, MSP payload bytes, credentials, filesystem paths, filenames, SSIDs, and user-visible device names are not retained.
3. **Private correlation.** Durable device IDs, route IDs, serial paths, and SSIDs become salted labels such as `device-12AB34CD` or `network-89EF0123`. A label is stable only inside one report and cannot correlate a tester across sessions.
4. **Bounded memory.** The recorder holds at most 10,000 events and approximately 2 MiB. When full, it removes debug/info events before warning/error events. Dropped counters make loss visible.
5. **Explicit export only.** Nothing is uploaded automatically. The tester explicitly invokes the diagnostics action. Dismissing the assistant permanently shuts down and clears the recorder.
6. **Deterministic text.** Stable sections, sorted event fields, ISO-8601 timestamps, and a schema version allow reports to be compared and parsed without depending on localized UI text.

## Export And Delivery Semantics

The diagnostics action remains visible throughout the assistant and takes a snapshot without cancelling or pausing an active import.

- The attachment name is `Airframe-FC-Diagnostics-yyyyMMdd-HHmmssZ.txt` in UTC.
- macOS asks the system sharing service to compose an email to `mail@danielkbx.com`. If the email service is unavailable, Airframe opens the native sharing picker.
- iPadOS uses the system mail composer when configured and otherwise opens the native activity sheet.
- The localized email subject/body provides context only. The text attachment is the diagnostic artifact.
- Airframe writes a temporary attachment file for native presentation. iPadOS removes it when the sheet finishes; both platforms remove or replace retained attachments when the assistant closes or another report is created.
- Creating a report does not upload or send it automatically; the tester reviews and submits the system sheet.

## Privacy And Evidence Boundary

The report is intended to answer how Airframe communicated, not what was stored in the log or configuration.

It may contain:

- Airframe version/build, Apple platform, OS version, hardware class, architecture, locale, and time zone.
- Assistant step, chosen import method, and broad assistant state.
- BLE authorization/state, RSSI, advertised/discovered service UUIDs, characteristic UUIDs and property flags.
- Resolved transport profile, write type, maximum write length, link-level byte counts, and safe error domain/code pairs.
- MSP version, command code/name, direction, attempt number, payload byte count, timeout/write/decoder state, but never payload bytes.
- Betaflight API/firmware/build/board metadata returned by the normal identity handshake.
- Dataflash capacity/usage, Blackbox storage type/sample-rate metadata, transfer sizes/counts, stages, and warning counts.

It must not contain:

- Blackbox log contents or decoded flight data.
- Betaflight configuration contents or CLI response contents.
- MSP, BLE, serial, TCP, or UDP payload contents.
- Raw CoreBluetooth UUIDs identifying a peripheral, USB serial paths, mount paths, filenames, or raw SSIDs.
- Credentials, personal filesystem paths, or cross-session identifiers.
- Internal development-system terminology in the exported text.

The final `[Excluded Data]` section declares these exclusions. Treat its presence as a format guard, not as proof by itself: inspect suspicious values if a future schema or new event field is introduced.

## Report Structure

### `[Report]`

- `schemaVersion`: choose the matching interpretation rules. Stop and inspect the implementation if newer than this runbook.
- `startedAt` / `generatedAt`: wall-clock session interval.
- `droppedVerboseEvents`: debug/info events evicted or rejected by recorder limits.
- `droppedCriticalEvents`: warning/error events rejected because only critical events remained. Any nonzero value materially limits diagnosis.

### `[Application]`

Use version/build and OS/platform first when comparing reports. Bluetooth behavior, platform APIs, and supported firmware paths can differ by build. Locale/time zone explain formatting and wall-clock context but are not device identity.

### `[Session]`

- `assistantStep`: step visible when the report was generated.
- `importMode`: `direct`, `wifi`, or `massStorage`.
- `assistantStatus`: broad state such as `idle`, `busy`, `connected`, `connectionFailed`, `complete`, or `failed`.

These values describe snapshot time, not necessarily the step where the original failure began. The event timeline is authoritative.

### `[Events]`

Each line contains sequence number, absolute timestamp, elapsed milliseconds since recorder creation, level, `component.name`, then sorted `key=value` fields. Use elapsed time for causal order and durations; use absolute time only to correlate with tester observations or separate system logs.

## Event Reference

### Session And Assistant

| Event | Meaning |
|---|---|
| `session.started` | Recorder initialized. It should be the first retained event unless verbose eviction occurred. |
| `assistant.step` | The assistant moved to a named step. |
| `assistant.importMode` | The user or default policy selected an import method. |

Repeated step or mode events are normal when the tester navigates backward or retries.

### Discovery

| Event | Important fields | Meaning |
|---|---|---|
| `discovery.bluetoothSnapshot` | `visible`, `likelyControllers` | Current replacement snapshot after Bluetooth filtering/classification. |
| `discovery.serialSnapshot` | `visible`, `devices` with hashed label/detail entries | Current macOS USB serial snapshot. Detail may include safe VID/PID-style metadata, never the callout path. |
| `bluetooth.centralState` | `state`, `authorization` | CoreBluetooth availability and permission state. |
| `bluetooth.scanStarted` | `serviceFilterCount` | Scan actually began. Airframe normally scans without a service filter. |
| `bluetooth.unavailable` | `state`, `authorization` | Scanning could not start because CoreBluetooth is unsupported or unauthorized. |
| `bluetooth.discovered` | hashed `device`, `rssi`, `advertisedServices`, `hasName` | Advertisement metadata. An empty service list is not failure; several supported adapters omit it. |

Diagnostic rules:

- No `scanStarted`: inspect central state/authorization first.
- `scanStarted` but no `discovered`: likely radio visibility, power, range, advertisement expiry, or OS scanning state; MSP is not involved yet.
- A device can be discovered with no advertised services and still connect successfully. Never reject compatibility from advertisement metadata alone.
- A device disappearing from a later snapshot does not prove a disconnect; advertisements expire independently of an established connection.

### Connection Route And Policy

| Event | Important fields | Meaning |
|---|---|---|
| `connection.attempt` | hashed `device`, `transport`, `rssi` | The assistant resolved a provider-owned route and began connecting. |
| `connection.deviceUnavailable` | — | The selected route was no longer owned by current discovery state. No transport attempt occurred. |
| `connection.policy` | `transport`, `continuousResponses`, `configurationCapture`, dataflash options | Post-connect profile capability was converted into import policy. |
| `connection.ready` | storage and dataflash metadata | Identity, capability/status capture, dataflash summary, and optional Blackbox configuration reached a usable state. |
| `connection.failed` | `error=domain:code` | Connection orchestration ended before ready. Read preceding transport/MSP events for the cause. |

The policy event is especially important for configuration failures:

- `continuousResponses=constrained` should select segmented configuration capture.
- Recognized split-characteristic BLE profiles and USB normally support complete dump capture.
- Unknown capability remains conservative. Do not infer capability from FC name, board name, manufacturer, or firmware alone.

### CoreBluetooth Setup

| Event | Important fields | Meaning |
|---|---|---|
| `bluetooth.connected` | hashed `device` | CoreBluetooth established the peripheral link. MSP has not yet been proven. |
| `bluetooth.servicesDiscovered` | `services` | Full discovered GATT service list. |
| `bluetooth.characteristicsDiscovered` | `service`, `characteristics`, `properties` | Characteristic layout and raw CoreBluetooth property flags. |
| `bluetooth.profileResolved` | `profile`, service/write/notify UUIDs, `writeType` | Airframe found a complete supported UART layout. |
| `bluetooth.notificationsEnabled` | `characteristic` | Notify/indicate subscription became active. |
| `bluetooth.transportReady` | profile, write type, `maximumWriteBytes` | Link is ready for MSP writes. |
| `bluetooth.configurationFailed` | hashed device, safe error | Service/characteristic/profile/notification setup failed. |
| `bluetooth.connectFailed` | hashed device, safe error | CoreBluetooth could not establish the peripheral connection. |
| `bluetooth.transportFailed` | safe error | The higher-level transport could not complete setup. |

Known profile interpretation:

- SpeedyBee V2: service `ABF0`, write `ABF1`, notify `ABF2` after UUID normalization.
- Shared-characteristic FFE0 UART: service `FFE0`, shared write/notify `FFE1`; this is the hardware-validated constrained T-Motor layout.
- Split FFE0/CC2541-style UART: service `FFE0`, write `FFE1`, notify `FFE2`.

Do not diagnose unsupported hardware merely because a known service exists. The complete service, characteristic UUID, property, and notification combination must resolve.

### Link-Level I/O

| Event | Important fields | Meaning |
|---|---|---|
| `bluetooth.write` | logical bytes, chunk count, maximum chunk size, write type | A logical transport write was split for CoreBluetooth. |
| `bluetooth.notification` | `bytes` | One nonempty notification reached the transport. Contents are excluded. |
| `bluetooth.writeFailed` | logical bytes, safe error | A transport write failed before MSP could receive a reply. |
| `bluetooth.writeAcknowledgementFailed` | characteristic, safe error | A with-response characteristic write was rejected/failed. |
| `bluetooth.notificationFailed` | characteristic, safe error | CoreBluetooth reported an error receiving characteristic data. |
| `bluetooth.streamDisconnected` / `bluetooth.disconnected` | safe error where available | The live link ended. Determine whether this was expected reboot/cleanup from neighboring import events. |
| `bluetooth.transportClosed` | — | Higher-level transport cleanup completed. This can be normal cancellation, reboot cleanup, or failure cleanup. |
| `serial.connected` | hashed device, baud | macOS opened and configured the serial route. |
| `serial.write` / `serial.read` | `bytes` | Link-level serial byte counts. |
| `serial.writeFailed` / `serial.disconnected` | safe error | Serial failure or terminal stream state. |

Link byte counts intentionally overlap MSP metadata. The overlap is useful: a link write with no MSP receive can distinguish local delivery from a protocol timeout, while notifications with decoder failures point toward framing/corruption rather than silence.

### MSP

| Event | Important fields | Meaning |
|---|---|---|
| `msp.tx` | version, code, symbolic command, payload byte count, attempt | A framed MSP request was handed to the transport. |
| `msp.rx` | version, code, command, direction, payload byte count | A valid MSP frame was decoded. |
| `msp.requestFailed` | code, command, attempt, reason | Request ended through `timeout` or `writeFailed`. |
| `msp.decoderFailure` | `kind` | Bytes arrived but MSP decoding found a framing/checksum/shape failure. |

Important commands currently named by the report:

| Code | Symbol | Diagnostic role |
|---:|---|---|
| 1 | `MSP_API_VERSION` | First handshake proof; receives one special retry because some BLE UARTs race immediately after notification enable. |
| 2 | `MSP_FC_VARIANT` | Confirms Betaflight-compatible firmware family. |
| 3 | `MSP_FC_VERSION` | Firmware version. |
| 4 | `MSP_BOARD_INFO` | Board/target identity metadata. |
| 5 | `MSP_BUILD_INFO` | Build date/time/revision/options metadata. |
| 68 | `MSP_SET_REBOOT` | Reboot or Mass Storage activation. An ensuing disconnect may be expected. |
| 70 | `MSP_DATAFLASH_SUMMARY` | Flash capacity, use, readiness, and support. |
| 71 | `MSP_DATAFLASH_READ` | Direct FlashFS transfer. Expect many repeated request/reply pairs. |
| 72 | `MSP_DATAFLASH_ERASE` | Destructive cleanup after successful materialization and confirmation. |
| 80 | `MSP_BLACKBOX_CONFIG` | Blackbox storage/sample metadata. |
| 84 | `MSP_STATUS_EX` | Bounded runtime-status baseline. |

Interpretation rules:

- `msp.tx` without a matching `msp.rx`, followed by `timeout`: the request was encoded and transport write completed, but no matching valid response arrived before the deadline.
- `writeFailed`: do not blame firmware response timing; the local link write did not complete.
- `decoderFailure` with notifications/serial reads: bytes arrived but were not a valid complete MSP frame. Look for checksum failures, framing mismatch, unexpected competing traffic, or truncation.
- An `rx` with `direction=unsupported` proves the FC answered and rejected that command. It is not a transport timeout.
- For the first code-1 request over BLE, two attempts with the second succeeding match the known post-notification startup race. Repeated later timeouts are a different failure.
- Numeric code `UNKNOWN` does not mean invalid traffic; it only means the report renderer has no symbolic label for that valid command yet.

### Controller And Storage Metadata

| Event | Important fields | Meaning |
|---|---|---|
| `controller.identified` | API, firmware, board/target/manufacturer, MCU/sample rate, build metadata | Full normal handshake succeeded. Signature/raw UID is deliberately excluded. |
| `dataflash.summary` | supported, ready, sectors, capacity/used bytes | Code 70 parsed successfully. |
| `blackbox.configuration` | supported, device, sample rate | Code 80 parsed successfully. |

If `controller.identified` is absent, do not reason about import-method behavior yet; the session did not complete identity. If identity exists but `connection.ready` does not, inspect status/dataflash/Blackbox requests between them.

### Direct Import

| Event | Meaning |
|---|---|
| `import.directStarted` | Direct import began with recorded option metadata. |
| repeated `MSP_DATAFLASH_READ` plus link events | FlashFS transfer shape. Compare addresses only if a future schema safely records them; schema 1 intentionally records counts, not payload/address contents. |
| `import.directCompleted` | Payload construction succeeded; fields include log count, total bytes, and warning count. |
| `import.directFailed` | Import failed with safe error domain/code. Read earlier events to separate transfer failure from readability validation. |

Large Direct imports can evict early verbose events. Use dropped counters and retained warning/error events before concluding that an expected request never occurred.

### Wi-Fi Import

Expected high-level order:

```text
import.wifiStarted
wifi.activating
MSP reboot/control activity over BLE
wifi.joining or wifi.manualJoinRequired
wifi.downloadProgress (sampled)
wifi.rejoiningPreviousNetwork
wifi.completed
import.wifiCompleted
```

Rules:

- `network-*` labels correlate join/manual-join events within the report without exposing the SSID.
- `wifi.downloadProgress` contains file index/count and packet counts, never filenames or packet contents. It is sampled at boundaries and every 64 aggregate packets.
- `wifi.noLogs` means the adapter exposed no downloadable log entries. It does not prove FlashFS was empty unless preceding adapter/firmware evidence establishes the selected storage path.
- A failure before `wifi.joining` is activation/BLE control. A failure after joining but before progress is Wi-Fi session/list/stat setup. Progress followed by failure is transfer/reassembly/session completion.
- `wifi.rejoiningPreviousNetwork` is a stage marker, not proof that restoration succeeded; schema 1 records completion/failure at the enclosing import level.
- `import.wifiFailed` is the enclosing safe error summary. Always prefer the preceding Wi-Fi, BLE, or MSP event as the causal boundary.

### Mass Storage Import

Expected high-level order:

```text
import.massStorageStarted
optional configuration capture/reconnect MSP activity
import.massStorageActivated
expected FC link loss/reboot
massStorage.volumeSelected
massStorage.volumeAccess
massStorage.copyCompleted or massStorage.noLogs/copyFailed
```

Rules:

- A disconnect directly after successful code 68 / `massStorageActivated` is expected and must not be diagnosed as a transport defect.
- `massStorage.selectionRejected reason=notPrepared` means volume selection arrived after the prepared import state was already lost; it is an assistant lifecycle/state boundary rather than filesystem evidence.
- `volumeAccess securityScoped=false` can be normal on macOS for an already accessible URL, but matters on sandboxed picker/provider paths. Interpret with platform and subsequent copy outcome.
- No mount path, volume name, source filename, or log content is retained.
- `copyCompleted` proves file copy plus readable-log inspection and payload construction succeeded. It includes log count, aggregate bytes, and warning count.
- `copyFailed reason=unreadableLogs` means communication and copying may have succeeded while the resulting Blackbox source was not readable. This is a content-validity boundary, not automatically a USB/BLE/MSC transport failure.
- `import.massStorageFailed` occurs before a usable preparation is returned, normally during configuration capture, reconnect, or reboot activation. Use the immediately preceding MSP/connection events rather than this summary alone.

## Mandatory Analysis Procedure

Follow this order for every received report.

### 1. Validate The Artifact

- Confirm the title and schema version.
- Confirm `[Excluded Data]` exists.
- Note application build, platform, OS, generated time, current mode/step/status.
- Record dropped verbose and critical counts. If critical drops are nonzero, state that the report is incomplete before giving a conclusion.
- Check whether the report begins late because verbose events were evicted.

### 2. Reconstruct The Timeline

- Use elapsed milliseconds, not line proximity alone.
- Mark retries, backward navigation, method changes, and separate connection attempts.
- Group events by hashed device label when more than one peripheral was observed.
- Do not combine evidence from different attempts unless the sequence explicitly reconnects the same session label.

### 3. Find The Last Proven Layer

Classify the last positive proof:

1. Scan started.
2. Device discovered.
3. Route attempt started.
4. Link connected.
5. Services/characteristics resolved.
6. Notifications enabled/transport ready.
7. First MSP response decoded.
8. Full identity completed.
9. Dataflash/Blackbox capability reads completed.
10. Import transfer began.
11. Transfer completed.
12. Readability validation and payload construction completed.

The first missing transition after the last positive proof is the primary fault boundary.

### 4. Identify The First Causal Failure

Prefer the earliest warning/error that explains later failures. A later `connection.failed` or `import.*Failed` is usually a summary, not root cause.

Examples:

- `centralState unauthorized` → permission boundary; later absence of discovery is secondary.
- Services found but no `profileResolved`, then `configurationFailed` → GATT layout/property mismatch.
- `transportReady`, code-1 TX, no notifications/RX, timeout → startup/link/FC MSP availability boundary.
- Notifications plus decoder failures → received-byte/framing integrity boundary.
- Identity and summary succeed, repeated code-71 timeout → Direct transfer-specific failure.
- Mass Storage activated and copied, then unreadable logs → source/readability boundary, not initial FC communication.

### 5. Rank Causes, Do Not Overclaim

Produce a ranked list with evidence for and against each cause. Distinguish:

- proven from report;
- strong inference from sequence;
- known hardware/firmware precedent from the connectivity Knowledge Base;
- missing evidence requiring a targeted retest.

Never claim the Mac, FC, BLE module, firmware, permissions, or source log is defective merely because it is the most familiar explanation.

### 6. Request The Smallest Useful Retest

Choose one action that crosses the failed boundary while changing one variable. Examples:

- Retry with FC power-cycled when the first MSP handshake is silent after a ready BLE transport.
- Verify Betaflight MSP is enabled on the documented UART when the shared FFE1 link is ready but every code-1 attempt is silent.
- Compare USB and BLE only when identity/capability behavior, not Blackbox contents, is under test.
- Retry without configuration capture only if policy/capture events localize failure to that phase.
- Ask whether the volume appeared in Files/Finder only when Mass Storage activated but no volume-selection event followed.

Do not request the tester's Blackbox file for a pure connection failure. Request a source log only when communication/copying completed and the unresolved question is parser/readability behavior, and only with explicit user consent.

## Diagnostic Response Template

Use this structure when reporting an analysis:

```text
Summary
- One-sentence fault boundary and confidence.

Proven sequence
- Last successful stages with decisive event names/timestamps.
- First causal failure.

Likely causes
1. Cause — supporting evidence; conflicting evidence.
2. Cause — supporting evidence; conflicting evidence.

Not supported
- Common explanations contradicted by the report.

Next test
- One minimal, concrete reproduction step.
- Exact diagnostics action to invoke afterward.

Missing evidence
- Only fields or observations required to distinguish the remaining causes.
```

Reference exact event names and elapsed times. Avoid pasting the entire attachment back to the user.

## Known Pattern Library

### Supported BLE Profile, First-Request Race

```text
bluetooth.profileResolved
bluetooth.notificationsEnabled
bluetooth.transportReady
msp.tx code=1 attempt=1
msp.requestFailed code=1 reason=timeout
msp.tx code=1 attempt=2
msp.rx code=1
controller.identified
```

Interpretation: known recoverable post-notification startup race. The session succeeded; do not label the BLE profile incompatible.

### MSP Disabled Or FC Silent Behind A Ready UART

```text
bluetooth.transportReady
msp.tx code=1 attempt=1
msp.requestFailed reason=timeout
msp.tx code=1 attempt=2
msp.requestFailed reason=timeout
```

Interpretation: UART link setup succeeded, but no valid MSP response arrived. For known T-Motor layouts, verify UART MSP configuration and power-cycle state before blaming GATT transport. Absence of notification bytes strengthens silence; notification bytes plus decoder errors changes the diagnosis to framing/integrity.

### Unsupported GATT Layout

```text
bluetooth.connected
bluetooth.servicesDiscovered
bluetooth.characteristicsDiscovered
bluetooth.configurationFailed
```

Interpretation: inspect service/characteristic UUIDs and property flags against registered profiles. No MSP request should be expected.

### Expected Mass Storage Reboot

```text
msp.tx command=MSP_SET_REBOOT
import.massStorageActivated
bluetooth.disconnected or serial.disconnected
massStorage.volumeSelected
massStorage.copyCompleted
```

Interpretation: disconnect is intentional. The import succeeded through the filesystem route.

### Transfer Succeeded, Source Unreadable

```text
identity and capability events succeed
transfer reaches expected byte/packet completion
massStorage.copyFailed reason=unreadableLogs
or import.directFailed after completed MSP reads
```

Interpretation: communication is not the leading cause. Continue with source integrity/parser evidence and the Blackbox compatibility Knowledge Base.

## Limitations Of Schema 1

- The report does not contain raw payloads, so it cannot independently prove payload semantics or reconstruct corrupt bytes.
- Direct-read addresses are not exported; repeated code-71 counts show transfer activity but not the exact missing address.
- Wi-Fi progress is sampled and does not expose every UDP reburst, CRC rejection, or socket transition.
- Network restoration has a stage marker but no dedicated success/failure result.
- OS-level CoreBluetooth, IOKit, NetworkExtension, and filesystem-provider logs are not embedded.
- The snapshot reflects one assistant lifetime. App termination before explicit export loses it.
- Bounded retention can remove early verbose events during large transfers.

State these limitations when they prevent a confident conclusion. Do not compensate by inventing evidence.

## Maintenance Contract

Update this runbook in the same change whenever any of the following changes:

- report schema version, sections, privacy exclusions, limits, or session lifecycle;
- event component/name or field semantics;
- registered BLE profiles or capability policy;
- MSP symbolic command mapping or retry policy;
- Direct, Wi-Fi, or Mass Storage stage ordering;
- attachment generation, recipient, or mail/share fallback;
- a newly observed hardware failure pattern materially changes diagnosis.

Every new diagnostic field must pass three questions before implementation:

1. Does it distinguish two plausible causes?
2. Can it be represented without payload contents, personal data, durable identifiers, or paths?
3. Is its volume bounded or safely evictable?

If any answer is no, do not add it to the report.
