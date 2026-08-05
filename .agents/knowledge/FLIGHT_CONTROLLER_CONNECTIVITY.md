# Flight Controller Connectivity

- Status: active
- Last reviewed: 2026-08-01
- Scope: Betaflight MSP/CLI transports, serial and BLE behavior, FlashFS, mass storage, helper hardware, and real-device validation
- Normative decisions: `../MEMORY.md`
- Related implementation: Airframe flight-controller import packages and app flows

## Evidence Matrix

| ID | Claim | Source | Grade | Scope | Airframe impact | Status |
|---|---|---|---|---|---|---|
| FCC-001 | Configurator treats serial, Web Bluetooth, and native BLE as byte transports beneath common MSP/CLI layers. | BFC | B | Pinned Configurator revision | Keep transports isolated from protocol/session logic. | verified |
| FCC-002 | SpeedyBee BLE advertisements cannot be relied on to expose a recognized service/name; service validation must occur after connection. | Local hardware tests, BFC | A/B | Adapter 3 | Publish discovery callbacks and validate profiles post-connect. | verified |
| FCC-003 | FlashFS download uses MSP 70/71; current source exposes SD summary but no equivalent MSP SD-file read. | BF-SRC | A | Current firmware revision | Direct MSP import is FlashFS-only; SD logs need filesystem/mass-storage access. | verified |
| FCC-004 | Sandboxed macOS serial access works with `com.apple.security.device.serial`; USB entitlement was unnecessary in tested hardware. | Local tests | A | macOS tested devices | Preserve the serial entitlement and IOKit/callout design. | verified |
| FCC-005 | iPadOS user-space CDC-ACM is unavailable under the no-DriverKit/no-MFi/no-private-API constraints. | SDK probes, Apple docs | A | iPadOS/Xcode 26.5 | Prefer BLE, mass storage through Files, or external helper architecture. | verified |

## Configurator and Protocol Findings

Reference repository: `betaflight-configurator/` at pinned commit `14a050b7b57b4addadc209e5b67b3cfd9fdef943`. Known SpeedyBee UART profiles include FF00/01/02, V1 1000/01/02, and V2 ABF0/1/2. Adapter 3 tests showed CoreBluetooth callbacks without a recognized advertised service/name, matching Configurator's connect-then-discover strategy.

The standard handshake requests API version, FC variant, FC version, board info, and build info. FlashFS uses `MSP_DATAFLASH_SUMMARY` 70, `READ` 71, and `ERASE` 72; erase originally remained disabled. Betaflight 4.5.4 added framed CLI backports, while 4.5.3 and older require interactive CLI. A tested 4.5.1 controller emitted a 39,370-byte/1,542-line dump then rebooted on `exit`; a newer framed controller returned 39,084 bytes/1,514 lines and restored MSP after ETX.

## macOS Hardware Validation

Tests on 2026-07-23 used a SpeedyBee F405 V5 at `/dev/cu.usbmodem0x80000001`. Directly mutating the bridged matching dictionary from `IOServiceMatching` caused optimized ARM64 `EXC_BAD_ACCESS`; matching `IOSerialBSDClient` then filtering services avoided it. `MSP_BUILD_INFO` revision may be arbitrary ASCII such as `norevis`, not necessarily a hash.

A full 8 MiB FlashFS download completed through 2,048 sequential 4,096-byte reads in about 132 seconds (~62 KiB/s). The modern seven-byte request contains address, length, and compression flag; the response carries address, actual length, compression type, and data. Maximum data is 4,096 bytes inside an MSP v1 jumbo response.

Adapter 3 exposed ABF0/ABF1/ABF2 after UUID normalization. Large uncompressed BLE reads were unreliable; 512-byte reads were stable. Compressed reads operate on complete 256-byte source chunks, can validly decode zero bytes when the budget is insufficient, and used fixed-tree Huffman encoding. A 400-byte budget survived 1,577 responses/837,120 decoded bytes but throughput stayed near 3.2 KiB/s.

The damaged `Logs/Faulty/LOG00004.bfl` fixture established that its real log end occurs at byte 744986 inside an 8 MiB dump; truncating the scanner segment there changes duration from 438.463 s to 1.261 s. It also exposed invalid/inverted graph-gap endpoints, which must be normalized before constructing ranges.

## iPadOS, MSC, and Helpers

Full platform feasibility is in [Apple Platforms and CI](APPLE_PLATFORMS_AND_CI.md) and [`USB-CDC-ACM-iPadOS-Report.md`](../../USB-CDC-ACM-iPadOS-Report.md). Betaflight's current MSC command is `msc`; MSP reboot modes 2/3 can request MSC but still require a transport. MSC is a reboot path checked early at boot, not a live switch. A configured physical MSC button is optional and often absent.

A helper attached to an MSP-enabled FC UART can download FlashFS without USB host. If it attaches to the FC USB port, it needs at least CDC-ACM host support. ESP32-S3 is the practical family: Espressif ESP32-S3-USB-OTG is the lowest-risk host validation board but lacks the preferred USB-C connector; Olimex ESP32-S3-DevKit-Lipo better matches USB-C/LiPo but host-role/VBUS behavior needs validation; LilyGO T-Display-S3 and SparkFun Thing Plus ESP32-S3 are higher-risk because documentation emphasizes device/power use.

## Specialized SpeedyBee Research

Detailed packet captures, protocol hypotheses, and experiment logs live in `../SPEEDYBEE_REVERSE_ENGINEERING.md`. They are deliberately not duplicated here.

## Source Register

| Source ID | Title | Author/project | Version/date | URL or local path | Accessed | Notes |
|---|---|---|---|---|---|---|
| BFC | Betaflight Configurator | Betaflight | commit `14a050b7b57b4addadc209e5b67b3cfd9fdef943` | `betaflight-configurator/` | 2026-08-01 | Pinned read-only reference |
| BF-SRC | MSP, VCP, MSC, and Blackbox source | Betaflight | tag `2026.6.1`, commit `6dbc4218fd6bc33bf16ea32c670304d4f89321d5` | `betaflight/src/main/` | 2026-08-05 | Primary stable firmware evidence; MSP API remains 1.48 and dataflash wire behavior is unchanged |
| AF-HW | Airframe hardware validation notes | Airframe research | 2026-07-23 through 2026-07-24 | Original `.agents/RESEARCH.md` history and test fixtures | 2026-08-01 | Reproducible local observations |
| SB | SpeedyBee reverse-engineering notebook | Airframe research | active | `.agents/SPEEDYBEE_REVERSE_ENGINEERING.md` | 2026-08-01 | Specialized lab notebook |
