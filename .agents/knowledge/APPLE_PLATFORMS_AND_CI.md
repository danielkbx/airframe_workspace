# Apple Platforms and CI

- Status: active
- Last reviewed: 2026-08-01
- Scope: Apple-platform API feasibility and Xcode Cloud signing constraints
- Normative decisions: `../MEMORY.md`
- Related implementation: Xcode project capabilities, CI configuration, and platform-specific transports

## Evidence Matrix

| ID | Claim | Source | Grade | Scope | Airframe impact | Status |
|---|---|---|---|---|---|---|
| APC-001 | iPhoneOS 26.5 app targets have no `IOUSBHost`, `USBDriverKit`, or `AccessoryAccess` module; `ExternalAccessory` is MFi-oriented. | Local SDK probes, Apple docs | A | Xcode/iPhoneOS 26.5 | Arbitrary user-space CDC-ACM is not feasible under the requested constraints. | verified |
| APC-002 | Apple's documented iPadOS external USB-driver route uses DriverKit on supported M-series iPads and requires entitlements/user approval. | Apple docs/DTS | A | Current Apple platform model | A no-DriverKit/no-private-API POC is out of scope. | verified |
| APC-003 | Xcode Cloud automatic capability provisioning does not establish that macOS unit-test products receive provisioning profiles for restricted entitlements. | Apple docs plus developer-forum report | B/D | macOS Xcode Cloud tests | Use a test-specific entitlement path omitting iCloud KVS while preserving it for archives. | partially verified |

## iPadOS USB Findings

The 2026-07-20 investigation is fully recorded in [`USB-CDC-ACM-iPadOS-Report.md`](../../USB-CDC-ACM-iPadOS-Report.md). Compile probes on Xcode 26.5/iPhoneOS 26.5 failed for `IOUSBHost`, `USBDriverKit`, and `AccessoryAccess`; `ExternalAccessory` compiled but does not provide arbitrary CDC-ACM access. DriverKit is the documented path and materially changes scope.

Betaflight uses `msc` for mass-storage mode. Firmware may enter it through CLI or `MSP_REBOOT` mode 2/3, but both still need a transport. Onboard FlashFS can be downloaded over MSP; current firmware has SD summary but no equivalent MSP SD-file reader. A helper MCU can use UART MSP without USB host, or an ESP32-S3-class USB host for CDC/MSC. Board candidates and risks are retained in [Flight Controller Connectivity](FLIGHT_CONTROLLER_CONNECTIVITY.md).

## Xcode Cloud Findings

Apple documents automatic capability inclusion for provisioning during CI archives, and iCloud KVS through `com.apple.developer.ubiquity-kvstore-identifier`. A 2025 developer-forum report showed restricted entitlements breaking macOS Cloud test products lacking an embedded profile. Airframe's pragmatic inference is to omit KVS from macOS build-for-testing/test products while retaining it for real Archive/Release builds.

## Source Register

| Source ID | Title | Author/project | Version/date | URL or local path | Accessed | Notes |
|---|---|---|---|---|---|---|
| AF-USB | USB CDC-ACM iPadOS Report | Airframe research | 2026-07-20 | `USB-CDC-ACM-iPadOS-Report.md` at workspace root | 2026-08-01 | Reproducible local SDK probes and source review |
| APPLE | DriverKit, provisioning, and iCloud capability documentation | Apple | current when researched | developer.apple.com documentation | 2026-08-01 | Primary platform documentation |
| FORUM | macOS Xcode Cloud restricted-entitlement report | Apple Developer Forums | 2025-05/06 | developer.apple.com/forums | 2026-08-01 | Community report; supports but does not prove Airframe inference |
