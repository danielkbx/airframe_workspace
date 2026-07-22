# Research Notes

## USB CDC-ACM Betaflight CLI on iPadOS

Investigation on 2026-07-20 concluded that the requested no-DriverKit/no-MFi/no-private-API iPadOS POC is not feasible.

- Technical report: `USB-CDC-ACM-iPadOS-Report.md`.
- Local SDK baseline: Xcode 26.5 / iPhoneOS 26.5.
- iPhoneOS app-target compile probes:
  - `import IOUSBHost` fails: no such module.
  - `import USBDriverKit` fails: no such module.
  - `import AccessoryAccess` fails: no such module.
  - `import ExternalAccessory` succeeds, but Apple's documentation positions it for MFi accessories and declared accessory protocols, not arbitrary USB CDC-ACM.
- Local SDK file search found `ExternalAccessory.framework` in the iPhoneOS SDK, but no `IOUSBHost.framework` or `AccessoryAccess.framework`. USBDriverKit lives in the DriverKit SDK, not the iPhoneOS app SDK.
- Apple's documented iPadOS route for external USB drivers is DriverKit on M-series iPads. That requires a driver extension, USB transport entitlement, iPadOS app-to-driver communication entitlement, user driver approval in Settings, and Apple entitlement approval for distribution.
- Apple DTS forum guidance for an iPadOS RP2040 CDC-ACM case says user-space serial APIs are unavailable; the proposed route is a DEXT implementing serial communication via raw USB commands plus a user client for the app.
- Current Betaflight and INAV mass-storage CLI command is `msc`, not `storage`. Betaflight docs and source agree: `CLI_COMMAND_DEF("msc", "switch into msc mode", ..., cliMsc)`.
- Betaflight VCP receives CLI payload bytes through USB OUT endpoint data (`VCP_DataRx` into the RX ring). It also handles CDC `SET_LINE_CODING`, `GET_LINE_CODING`, and `SET_CONTROL_LINE_STATE`; a future DriverKit implementation should send the standard control requests for robustness even if the CLI payload itself is bulk data.
- Betaflight also exposes MSC entry through MSP, not only CLI. `MSP_REBOOT` command 68 accepts one-byte reboot modes where `MSP_REBOOT_MSC` is value 2 and `MSP_REBOOT_MSC_UTC` is value 3. The MSP handler checks `mscCheckFilesystemReady()` for MSC mode and then schedules `systemResetToMsc(...)`. This still requires a working MSP transport, usually the same USB CDC/VCP path, but it avoids CLI prompt-state parsing.
- Firmware-side MSC entry is implemented as a reboot flag, not a live USB mode switch. `systemResetToMsc(...)` writes `RESET_MSC_REQUEST` to persistent storage and resets. Early boot checks `mscCheckBootAndReset() || mscCheckButton()` before initializing VCP; if true it starts MSC and does not return to the normal scheduler. A physical/configured `USB_MSC_BUTTON_PIN` can also enter MSC at boot, but the default is `NONE` and many boards will not expose a usable button path.
- Betaflight's legacy Blackbox download path uses MSP over the normal serial/VCP connection, not MSC. `MSP_DATAFLASH_SUMMARY` reports FlashFS support/readiness, sector count, size, and current offset. `MSP_DATAFLASH_READ` reads onboard flash by absolute address in chunks; payload is address plus optional read length and compression flag, with a 128-byte legacy fallback when only the address is sent. `MSP_DATAFLASH_ERASE` erases via `blackboxEraseAll()`. `MSP_SDCARD_SUMMARY` exposes SD-card state/free/total space, but current firmware source does not show an equivalent MSP file-read command for SD-card Blackbox logs; SD-card/on-filesystem access is the MSC/FAT path.
- External helper-device architecture: if a helper talks to Betaflight over a hardware UART with the MSP function enabled, it does not need USB host support to download onboard FlashFS Blackbox logs. A small MCU such as an ESP32 can use 3.3 V TTL UART, request `MSP_DATAFLASH_SUMMARY`, then chunk through `MSP_DATAFLASH_READ` and expose the result onward over Wi-Fi/BLE or, on USB-capable ESP32 variants, as a USB device. USB host support is only required when the helper itself needs to operate the FC's USB CDC/MSC interface.
- If a helper connects to the FC's USB port and speaks MSP over Betaflight VCP/CDC, the helper still needs USB host support, but only CDC-ACM host support rather than MSC/FAT. ESP32-S3 is the practical ESP32 family choice. Espressif's ESP-IDF USB Host docs include CDC-ACM host and MSC host class-driver examples. Board shortlist from 2026-07-21 research: Espressif ESP32-S3-USB-OTG is the safest USB-host validation board because it has a Type-A host port, Li battery charging, battery-boosted 5 V host power, and 500 mA host current limiting, but it does not meet a USB-C-port preference. Olimex ESP32-S3-DevKit-Lipo best matches USB-C plus LiPo charger and native USB OTG in a compact board, but its USB-C host-role/VBUS behavior should be verified against the schematic or with a prototype before treating it as a plug-and-play FC host. LilyGO T-Display-S3 and SparkFun Thing Plus ESP32-S3 are attractive USB-C/LiPo ESP32-S3 boards, but available docs emphasize device/power use more than a ready USB-host power path, so they are higher-risk first choices for FC USB hosting.

## Upstream Blackbox Explorer

The official viewer is currently a Vite/Vue PWA, not an Electron app.

Important files:

- `blackbox-log-viewer/src/flightlog_parser.js`: low-level Blackbox parser.
- `blackbox-log-viewer/src/decoders.js`: advanced field decoders.
- `blackbox-log-viewer/src/datastream.js`: byte stream abstraction.
- `blackbox-log-viewer/src/flightlog_index.js`: log offset and intraframe indexing.
- `blackbox-log-viewer/src/flightlog.js`: higher-level model, chunking, computed fields, smoothing, seeking.
- `blackbox-log-viewer/src/flightlog_fielddefs.js`: field constants, firmware types, events.
- `blackbox-log-viewer/src/flightlog_fields_presenter.js`: field presentation and unit conversion.
- `blackbox-log-viewer/src/graph_config.js`: default graph definitions and field grouping.
- `blackbox-log-viewer/src/grapher.js`: Canvas graph rendering and interaction.
- `blackbox-log-viewer/src/graph_spectrum_calc.js`: spectrum and FFT calculations.
- `blackbox-log-viewer/src/graph_map.js`: Leaflet-based GPS map view.
- `blackbox-log-viewer/src/craft_3d.js`: Three.js craft visualization.
- `blackbox-log-viewer/src/flightlog_video_renderer.js`: WebM export using canvas and `webm-writer`.

Approximate file sizes from the first pass:

- `flightlog_fields_presenter.js`: 3130 lines.
- `flightlog_parser.js`: 1901 lines.
- `flightlog.js`: 1844 lines.
- `graph_config.js`: 1692 lines.
- `grapher.js`: 1282 lines.

The parser and data model are mostly plain JavaScript and are conceptually portable. The UI/rendering side is strongly browser-dependent through Canvas, DOM events, `<video>`, Leaflet, Three.js, and WebM export.

## Spectrum Analyser Reference (for deferred views and overlays)

Captured 2026-07-15 from `blackbox-log-viewer/src/graph_spectrum_calc.js`, `graph_spectrum_plot.js`, `components/SpectrumAnalyser.vue`.

- Upstream modes: Frequency, Freq vs Throttle, Freq vs RPM (implemented natively), plus Power Spectral Density, PSD vs Throttle, PSD vs RPM, PID Error vs Setpoint (backlogged).
- PSD: Welch method, `_pointsPerSegmentPSD` default 512 (user range 2^6..next power of two of the sample count), 75% overlap for multi-segment, Hanning scale `1/(rate*sum(win^2))`, dB via `10*log10` with a 1e-7 floor (-70 dB), max-noise search above 50 Hz. PSD heatmaps clamp with minPSD (-40 dB default), maxPSD (+10 dB), lowLevelPSD (values below map to minPSD).
- Filter overlays read sysConfig: gyro_lowpass_dyn_hz[min,max] + gyro_lowpass_dyn_expo + gyro_soft_type, gyro_lowpass_hz, gyro_lowpass2_hz + gyro_soft2_type, gyro_notch_hz/gyro_notch_cutoff (arrays or scalars), dterm equivalents (dterm_lpf_dyn_hz, dterm_lpf_dyn_expo, dterm_filter_type, dterm_lpf_hz, dterm_lpf2_hz, dterm_notch_hz/cutoff), yaw_lpf_hz, and motor_poles. Airframe already exposes these through `ReaderHeaderSemanticValue` keys (gyroLPF1*, dterm*, rpmFilter*, motorPoles).
- Overlay drawing: static cutoffs are labeled vertical lines; the dynamic LPF in Freq-vs-Throttle draws the expo curve `f = min + (max-min) * (t*(1-t)*expo + t)` over the throttle axis; overdraw filter modes are all/gyro/dterm/yaw/hide/auto, where auto keys off the analysed field name (gyro / pid d / yaw). Native plug-in point: `SpectrumSurfaceCanvas(overlays:)` with `SpectrumOverlay.verticalLine/.curve` plus a future `makeFilterOverlays(headerInfo:mode:)` builder in the app model.
- Frequency-view display scaling is absolute, not max-normalized: bar height = magnitude * HEIGHT/(zoomY*100); heatmap lightness = clamp(magnitude * 100/(zoomY*1.1)); zoomY = 1/(sliderPercent/100). Native `SpectrumIntensity` reproduces exactly this.
- Upstream `rcCommands[3]` throttle percent = clamp((rcCommand[3]-minthrottle)/(maxthrottle-minthrottle)*100, 0, 100) (flightlog.js `rcCommandRawToThrottle`); the native sample source uses the same formula with defaults 1150/1850.
- RPM notch overlay research (2026-07-17): PTB Pro's RPM notch harmonic overlay has no open implementation or published math. OS PIDtoolbox (v0.23) contains no notch overlay code at all; blackbox-log-viewer parses rpm_filter headers but never draws them; the PTB Pro Patreon post is supporter-gated and the release note only names the feature. Betaflight firmware math (rpm_filter.c, dshot.c): motorHz = eRPM_log_value × 3.333 / motor_poles; notch center per harmonic k = clamp(k × motorHz, rpm_filter_min_hz, 0.48e6/looptimeUs); fade weight = clamp((center − minHz)/rpm_filter_fade_range_hz, 0, 1) × rpm_filter_weights[k−1]/100; max 3 harmonics. Airframe's implemented curve semantics (empirical distribution of the notch center; see MEMORY 2026-07-17) are a derived hypothesis: monotone-rising sigmoid shape and the 2×/3× horizontal shift of higher harmonics in the PTB screenshots exclude a filter magnitude response and match a CDF exactly.

## Format Notes

Betaflight Blackbox logs contain multiple frame types. The reference parser handles at least:

- `I`: intraframes.
- `P`: interframes.
- `S`: slow frames.
- `G`: GPS frames.
- `H`: GPS home frames.
- `E`: event frames.

The format uses per-field predictors and encodings. Robust decoding matters because logs can have dropped or corrupt frames, and the decoder may need to resynchronize.

Useful documentation:

- Betaflight Blackbox guide: https://betaflight.com/docs/wiki/guides/current/Black-Box-logging-and-usage
- Betaflight Blackbox internals: https://betaflight.com/docs/development/Blackbox-Internals
- Official viewer: https://github.com/betaflight/blackbox-log-viewer
- Official tool reference: https://github.com/betaflight/blackbox-tools

## Related Parser Projects

Potential references, not yet deeply evaluated:

- `blackbox_log` Rust crate: https://docs.rs/blackbox-log/latest/blackbox_log/
- `bbl_parser` Rust crate: https://docs.rs/bbl_parser
- `blackbox-log-ts`: TypeScript/WASM parser based on Rust.
- `orangebox`: Python parser modeled after Blackbox Log Viewer.

Since the user prefers Swift, these are mainly useful as behavioral references and test oracles.

## Firmware Source Reference

The Betaflight firmware repository is relevant because it contains the code that writes Blackbox logs. It should be used as a primary reference for:

- Which runtime data is written into each frame type.
- Header names and firmware-version-specific fields.
- Predictor and encoding choices from the writer side.
- Blackbox feature evolution across Betaflight versions.
- Edge cases that may not be obvious from the viewer parser alone.

Potential upstream repository:

- https://github.com/betaflight/betaflight

Local clone:

- `betaflight/`
- Observed commit: `b89b33963fbeea2ff91e08ebddd97247307fd458`
- Commit date: `2026-07-06 18:37:05 +1000`
- Commit subject: `fix(flashfs): avoid blocking MSP during NOR chip erase (#15273)`

Blackbox writer and related files found in the firmware repo:

- `betaflight/src/main/blackbox/blackbox.c`
- `betaflight/src/main/blackbox/blackbox.h`
- `betaflight/src/main/blackbox/blackbox_encoding.c`
- `betaflight/src/main/blackbox/blackbox_encoding.h`
- `betaflight/src/main/blackbox/blackbox_fielddefs.h`
- `betaflight/src/main/blackbox/blackbox_io.c`
- `betaflight/src/main/blackbox/blackbox_io.h`
- `betaflight/src/main/blackbox/blackbox_virtual.c`
- `betaflight/src/main/blackbox/blackbox_virtual.h`
- `betaflight/src/test/unit/blackbox_unittest.cc`
- `betaflight/src/test/unit/blackbox_encoding_unittest.cc`

Related settings and CLI references:

- `betaflight/src/main/cli/settings.c`
- `betaflight/src/main/cli/settings.h`

The firmware-side unit tests may be useful as behavioral references and validation data for independently written Swift encoders/decoders.

### Writer/Viewer Compatibility Audit Notes

Current focused audit findings:

- Current Betaflight firmware writer emits frame markers `I`, `P`, `S`, `H`, `G`, and `E`.
- The reference viewer parser dispatches those same frame markers.
- Current firmware predictor IDs are `0...11`; these match the reference viewer parser constants.
- Current firmware encoding IDs are `0`, `1`, `3`, `6`, `7`, `8`, `9`, and `10`; these match the current Swift raw value decoder set.
- Current firmware event types observed in `blackbox.h` are sync beep, inflight adjustment, logging resume, disarm, flight mode, and log end. The reference viewer parser reads these and also retains legacy handlers for older unused event IDs.
- Flight-mode `E` frames carry current and previous `rcModeActivationMask` bitsets, not an event timestamp. Disarm, flight-mode, log-end, and unknown events often have no payload timestamp, so Airframe's human timeline uses the latest valid main-frame time as event context and keeps explicit event time only when the payload provides one.
- Betaflight flight-mode event payloads currently store 32-bit flag values. The current Betaflight `boxId_e` list contains more than 32 boxes, but Blackbox event records only preserve the first 32 bits.
- Betaflight does not encode `Acro` as a flight-mode bit. Current telemetry/OSD code treats `Acro` as the fallback display when higher-priority modes such as failsafe, GPS rescue, position/altitude hold, angle, horizon, and similar modes are inactive.
- Betaflight flight-mode flag names are firmware-version-sensitive. For Betaflight `4.0+`, the Blackbox Explorer table removes legacy `BARO`, `GPSHOME`, and `GPSHOLD`; for `3.5+`, it removes `RANGEFINDER`, `CAMTRIG`, `LEDMAX`, `LLIGHTS`, `GOV`, and `GTUNE`. Airframe CLI text output uses the firmware revision to derive concise names such as `arm`, `disarm`, and `flightMode Air`, while JSON/NDJSON retain the raw flag payload. A full revision string like `Betaflight 4.4.3 (hash) STM32...` must parse the first version-like token, not the last whitespace token.
- Current firmware GPS `G` field definitions can include `GPS_velned[0...2]` and `GPS_time`.
- Current firmware GPS home `H` definitions can include `GPS_home_epoch`.
- The reference viewer parser can decode dynamic header-defined fields generically, but higher viewer model/presentation code may ignore or only partially use some decoded fields such as `GPS_home_epoch`.
- Airframe should preserve unknown headers and dynamic fields instead of modeling only the fields visibly used by the reference viewer UI.
- Header metadata audit against the current Betaflight writer found naming drift between Airframe's current header catalog and current emitted header names:
  - Current comparison baseline: Airframe currently catalogs 195 known header names and 16 aliases; the current Betaflight writer emits 235 distinct non-frame header names in `betaflight/src/main/blackbox/blackbox.c`; 111 match directly, 3 match only through aliases, 124 emitted writer names are currently unknown to Airframe, and 81 Airframe-known names are not emitted by the current writer under those names.
  - Current Betaflight writes `thr_mid`, `thr_expo`, `vbat_scale`, `pid_at_min_throttle`, `pidsum_limit`, and `pidsum_limit_yaw`; Airframe currently recognizes legacy/camel-case forms such as `thrMid`, `thrExpo`, `vbatscale`, `pidAtMinThrottle`, `pidSumLimit`, and `pidSumLimitYaw`.
  - Current Betaflight writes `dyn_idle_min_rpm`; Airframe currently recognizes `dynamic_idle_min_rpm`.
  - Current Betaflight writes cell voltage thresholds as one `vbatcellvoltage` list: min, warning, max.
  - Current Betaflight writes ADC current calibration as `currentSensor` offset,scale only for ADC current meter; Airframe currently maps `currentSensor` to `currentMeter`, which is semantically wrong for display.
  - Current Betaflight writes `rc_rates` and `rc_expo` as roll,pitch,yaw lists; standalone yaw-rate/yaw-expo display should derive from the third list value rather than require `rcYawRate` or `rcYawExpo`.
  - Suspicious current aliases: `currentSensor -> currentMeter` collapses two different concepts; `d_max -> d_min` collapses distinct PID values; `motor_pwm_protocol -> fast_pwm_protocol` is reasonable as legacy compatibility.
  - Important current writer names missing from Airframe's known catalog include newer filter, feedforward, motor, dynamic idle, GPS rescue, altitude/autopilot, TPA, and RC smoothing names such as `gyro_lpf1_*`, `dterm_lpf1_*`, `feedforward_*`, `rpm_filter_*`, `motor_idle`, `use_unsynced_pwm`, `gps_rescue_*`, `altitude_*`, `ap_*`, `tpa_curve_*`, and `tpa_speed_*`.
  - Airframe's known catalog still contains many legacy names not emitted by the current writer, such as `Blackbox version`, `P denom`, `thrMid`, `thrExpo`, `vbatscale`, `pidAtMinThrottle`, `pidSumLimit`, `pidSumLimitYaw`, `dynamic_idle_min_rpm`, older dynamic-filter names, and older feedforward `ff_*` names.
  - `debug_mode` controls debug frame semantics; it does not explain missing battery/current/receiver setup headers.
- Header metadata implementation update: `BlackboxReader` now owns canonical header recognition and semantic values. Modern/current names such as `thr_mid`, `thr_expo`, `vbat_scale`, `dyn_idle_min_rpm`, `gyro_lpf1_*`, `dterm_lpf1_*`, `feedforward_*`, `rpm_filter_*`, `motor_idle`, `use_unsynced_pwm`, `gps_rescue_*`, `altitude_*`, and `ap_*` are recognized in Reader. The bad `currentSensor -> currentMeter` and `d_max -> d_min` conflations were removed; current sensor calibration and D-min/D-max remain distinct. Derived semantic values cover `vbatcellvoltage` min/warning/max, `rc_rates` yaw rate, `rc_expo` yaw expo, and `currentSensor` offset/scale.
- Header display implementation update: `DecodedLogFlightInfo.infoReport(showEmpty:)` formats clear unit-bearing setup values for consumers. `vbatcellvoltage` entries are centivolts and display as volts with two decimals, e.g. `340` becomes `3.40 V`. Filter/PWM/rpm-filter frequency fields display as Hz; dynamic idle min displays as RPM; motor KV displays as KV; GPS rescue distance/altitude fields display as meters; selected delay/smoothing fields display as ms; angle limits display as `deg`. Calibration values such as voltage scale/reference and current scale/offset remain raw until their units are proven.
- Header report API update: `ReaderInfoRow` now keeps `displayValue`, `rawValue`, and `typedValue` separate. `value` remains a display-value compatibility alias. CLI `info --format json` emits all value forms for each row so agent consumers can use raw/typed values without stripping units from human display strings.

Initial Airframe compatibility baseline:

- Safely supported claim starts at Betaflight `4.4.3` with Blackbox `Data version:2`.
- Local full-log staging currently includes Betaflight `4.4.3`, `4.6.0`, and `2025.12.5`-style logs.
- Older Betaflight versions remain best-effort/unsupported until specific fixtures and golden outputs are added.

## Licensing

The official viewer is GPL-3.0. GPL-3.0 is acceptable if code is reused or ported, but it is not automatically required for an independently written implementation based on public format behavior and original Swift design. App Store distribution is not required.

## Xcode Cloud macOS Tests With iCloud Entitlements

Research on 2026-07-12 found no Apple-documented supported recipe for running macOS Xcode Cloud test products with iCloud Key-Value Storage entitlements under the local/ad-hoc signing used by Cloud test tasks.

Relevant Apple facts and signals:

- Apple's Xcode Cloud overview/get-started material positions Cloud as CI/CD that builds and runs automated tests on Apple-hosted infrastructure.
- Apple's provisioning-with-capabilities documentation says Xcode Cloud sees the latest App ID configuration during CI and automatically includes enabled capabilities in provisioning profiles for automatic signing.
- Apple's iCloud service documentation says iCloud KVS is enabled through the iCloud capability and `com.apple.developer.ubiquity-kvstore-identifier`.
- Apple Developer Forums include a May/June 2025 macOS Xcode Cloud report where adding a restricted entitlement such as Keychain Sharing makes macOS unit tests fail with code-signing issues; the reporter observed that local builds embed `embedded.provisionprofile`, while Xcode Cloud test products do not. Their temporary workaround was deleting the restricted entitlement in `ci_post_clone` for macOS `build-for-testing`.

Airframe inference:

- Archive/distribution signing and macOS test-product signing are different paths in Xcode Cloud.
- Enabling the App ID capability is still required for real app builds, but it does not by itself prove that macOS test products get a usable provisioning profile.
- For Airframe's current Xcode Cloud macOS failure, the pragmatic CI fix is a test/build-for-testing-specific macOS entitlement path that omits the iCloud KVS entitlement while keeping App Sandbox and user-selected read-only file access. Product Archive/Release builds should keep iCloud KVS.

## Graph Section Layout Research

- The reference graph renderer takes ordered graph definitions with a label, a field list, and a height weight (default `1`). It sums the weights, allocates each graph a normalized vertical band in that order, and leaves a small inter-section gap.
- Every section receives the same document time window and shares the global current-time bar and event overlays. Each section calculates its own Y projection/grid from its assigned fields, so only the X axis is synchronized.
- Airframe should retain only ordered section names and ordered semantic series IDs in document state. Future native rendering uses equal-height sections, one shared time domain, and independent per-section Y domains; height weights, curves, colors, and smoothing are deliberately out of scope.
- The reference viewer creates `Motors` and `Gyros` when no user graph configuration exists. Airframe mirrors that small default only for newly materialized Graph setups: motor channels in `Motors`, gyro channels in `Gyros`; Table keeps its separate Core Tuning defaults.
