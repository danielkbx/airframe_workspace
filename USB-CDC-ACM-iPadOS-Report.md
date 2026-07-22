# USB CDC-ACM Betaflight CLI on iPadOS

Date: 2026-07-20

## Summary

A normal native iPadOS App Store application cannot communicate directly with a Betaflight or INAV USB CDC-ACM flight controller over USB-C using public APIs, without DriverKit, private APIs, MFi, or extra hardware.

The planned one-button POC should not be built under those constraints because the required USB access API is not available to an iPadOS app target in the installed iPhoneOS 26.5 SDK:

- `IOUSBHost` import fails for iPhoneOS: no module.
- `USBDriverKit` import fails for iPhoneOS app targets: no module.
- `AccessoryAccess` import fails for iPhoneOS: no module in the installed SDK.
- `ExternalAccessory` imports successfully, but it is for MFi accessories and declared accessory protocols, not arbitrary USB CDC-ACM devices.

DriverKit can solve this class of problem on supported iPads, but that violates the stated POC constraint. It also requires a DriverKit extension, USB transport entitlement, app/driver communication entitlement, user approval in Settings, and distribution entitlement approval from Apple.

## Research Questions

### 1. Can an App Store iPad app communicate with USB CDC ACM devices?

**Answer: No, not directly under the stated constraints.**

Apple's normal app framework available on iPhoneOS/iPadOS is `ExternalAccessory`, which Apple describes as communication with MFi accessories over physical accessory connectors or Bluetooth. The manufacturer controls which apps can communicate with the accessory. That does not match a generic Betaflight USB CDC ACM device.

Apple's USB stack for raw USB access is exposed through `IOUSBHost` on macOS and through `USBDriverKit` for DriverKit drivers. Apple documents iPadOS DriverKit support for iPadOS 16+ on M-series iPads, including USBDriverKit, but this is a driver-extension model, not a normal app model.

Apple's DriverKit entitlement docs also state that iPadOS apps need `com.apple.developer.driverkit.communicates-with-drivers` to open user clients to drivers. Driver entitlements themselves must be requested from Apple for distribution.

Local SDK evidence:

```text
iPhoneOS SDK: /Applications/Xcode-26.5.0.app/.../iPhoneOS26.5.sdk
import IOUSBHost       -> no such module 'IOUSBHost'
import USBDriverKit    -> no such module 'USBDriverKit'
import AccessoryAccess -> no such module 'AccessoryAccess'
import ExternalAccessory -> typecheck succeeds
```

The iPhoneOS 26.5 SDK contains `ExternalAccessory.framework`, but not `IOUSBHost.framework` or `AccessoryAccess.framework`. USBDriverKit is present in the DriverKit SDK, not the iPhoneOS app SDK.

Relevant sources:

- Apple ExternalAccessory documentation: https://developer.apple.com/documentation/externalaccessory
- Apple DriverKit for iPadOS documentation: https://developer.apple.com/documentation/driverkit/creating-drivers-for-ipados
- Apple DriverKit entitlement request documentation: https://developer.apple.com/documentation/DriverKit/requesting-entitlements-for-driverkit-development
- Apple `Communicates with Drivers` entitlement: https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.developer.driverkit.communicates-with-drivers
- Apple USBDriverKit documentation: https://developer.apple.com/documentation/usbdriverkit
- Apple DTS forum answer on iPadOS CDC/serial: https://developer.apple.com/forums/thread/826070

### 2. Can raw USB endpoints be accessed?

**Answer: Not from a normal iPadOS app target in the installed SDK.**

The required raw USB concepts exist in these places:

- macOS app/user-space USB: `IOUSBHost`.
- DriverKit driver extension: `USBDriverKit`, with `IOUSBHostDevice`, `IOUSBHostInterface`, and `IOUSBHostPipe`.
- Future/beta macOS path: `AccessoryAccess`, which can open USB accessories and expose descriptor data, but it is beta and not present in the iPhoneOS 26.5 SDK used here.

The normal iPadOS app SDK does not expose a public API to enumerate arbitrary USB devices, inspect interfaces/endpoints, open Bulk IN/Bulk OUT pipes, or perform generic USB transfers.

Apple DTS's May 2026 answer on an iPadOS RP2040 CDC-ACM case says the serial-port-style user-space APIs are not available, and the route is a DriverKit extension implementing serial communication using raw USB commands, plus a user client that the app talks to.

### 3. Does Betaflight require a complete CDC implementation?

**Answer: The CLI byte stream itself is bulk endpoint data, but a robust host/driver should still implement enough CDC control behavior.**

Betaflight's current VCP path receives host bytes through the USB OUT endpoint and puts them into the VCP RX ring buffer. Source reference:

- `betaflight/src/platform/X32/usbhs/vcp/usbd_cdc_vcp.c`
- `VCP_DataRx(...)` copies USB OUT packet bytes into `usbRxBuffer`.
- `CDC_Receive_DATA(...)` is then used by the serial VCP layer.

Betaflight also handles CDC control requests:

- `SET_LINE_CODING`: stores line coding and calls a baud-rate callback if registered.
- `GET_LINE_CODING`: returns stored line coding.
- `SET_CONTROL_LINE_STATE`: stores DTR/RTS and calls a control-line-state callback if registered.
- Other PSTN requests are ignored safely.

For the narrow CLI goal, the meaningful payload is:

```text
#
msc
```

Current Betaflight documentation and source use `msc`, not `storage`, for mass-storage mode. INAV references found during this pass also use `msc`.

Betaflight source reference:

- `betaflight/src/main/cli/cli.c`
- `CLI_COMMAND_DEF("msc", "switch into msc mode", ..., cliMsc)`
- `cliMsc(...)` prints "Restarting in mass storage mode", waits for serial TX to finish, shuts down motors, and calls `systemResetToMsc(...)`.

Betaflight docs:

- CLI command reference: https://betaflight.com/docs/wiki/guides/current/Cli
- Mass storage support: https://www.betaflight.com/docs/wiki/guides/current/Mass-Storage-Device-Support

INAV references:

- INAV 2.4 release note mentions new `msc` CLI command: https://newreleases.io/project/github/iNavFlight/inav/release/2.4.0
- INAV USB MSC usage references use `msc`: https://docs.corewing.com/en/plane/other/inav/usb-msc.html

### 4. Existing projects

Search found references and forum examples around:

- IOUSBHost use on macOS.
- USBDriverKit/SerialDriverKit drivers.
- iPadOS CDC/serial attempts that converge on DriverKit.
- Configurator-style app workflows using `msc`.

No open-source Swift project was found that demonstrates a normal iPadOS App Store app directly opening a CDC-ACM device and using bulk endpoints without DriverKit, MFi, or private APIs.

The most relevant Apple DTS answer explicitly says that for iPadOS CDC-style USB serial, the user-space serial APIs are unavailable and the implementation requires a DriverKit extension with raw USB commands and a user client.

## API and Entitlement Matrix

| Path | iPadOS normal app? | Required entitlement | App Store possible? | Fits constraints? |
| --- | --- | --- | --- | --- |
| `ExternalAccessory` | Yes | MFi/protocol setup | Yes, with MFi/accessory support | No |
| `IOUSBHost` directly | No in iPhoneOS 26.5 SDK | macOS USB sandbox entitlement for sandboxed Mac apps | macOS path, not iPadOS app path | No |
| `USBDriverKit` DriverKit extension | Yes on supported iPads, as a driver extension | DriverKit, USB transport, communicates-with-drivers; distribution approval | Possible with Apple entitlement approval and user driver approval | No, DriverKit excluded |
| `AccessoryAccess` | Not in iPhoneOS 26.5 SDK; beta docs point to USB access via IOUSBHost | `com.apple.developer.accessory-access.usb` | Beta/unclear; macOS release notes mention it | No current iPadOS POC basis |
| Private APIs / jailbreak | Technically possible in theory | N/A | No | No |

## App Store Distribution

Under the requested no-DriverKit/no-MFi/no-private-API constraints, App Store distribution is not possible because there is no public iPadOS app API to open the USB CDC ACM interface.

With DriverKit, App Store distribution may be possible, but it becomes a different project:

- M-series iPad required.
- DriverKit extension required.
- USB transport entitlement required.
- iPadOS app-to-driver entitlement required.
- User must enable the driver in Settings.
- Apple must approve the DriverKit entitlements for distribution.

## Feasibility Decision

Do not build the requested POC as originally constrained. The one-button app cannot perform the USB operation on iPadOS using public normal-app APIs.

The closest feasible alternatives are:

1. **DriverKit version**: implement a USBDriverKit driver that claims the FC's CDC interface and exposes a tiny user client command (`startMassStorageAccess`) to the app. This is technically plausible but explicitly outside the requested constraints.
2. **Firmware-side alternative transport**: expose a supported iPadOS transport such as USB Ethernet/RNDIS-like networking if firmware/hardware can support a class iPadOS accepts. This changes the device-side implementation.
3. **External hardware bridge**: BLE/Wi-Fi/Lightning-MFi/USB accessory bridge that speaks serial to the FC and supported app transport to iPadOS. This violates the no-additional-hardware constraint.
4. **macOS companion utility**: trivial via `/dev/cu.usbmodem...`, but does not solve iPadOS.

## If Constraints Change

Recommended DriverKit POC shape:

- App: SwiftUI, iPadOS only, one button `Start Mass Storage Access`, read-only log pane.
- Driver: USBDriverKit DEXT matching the FC VID/PID/interface or CDC ACM class/subclass/protocol.
- Driver behavior:
  - Open CDC control and data interfaces.
  - Optionally send `SET_LINE_CODING` and `SET_CONTROL_LINE_STATE(DTR|RTS)` for compatibility.
  - Write `#\r\n`, wait briefly for CLI prompt, write `msc\r\n`.
  - Read/log IN endpoint data until disconnect.
  - Report disconnect/reconnect observations to the app.

This is not the requested POC, but it is the technically coherent path.
