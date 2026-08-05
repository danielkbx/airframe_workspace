# Blackbox Format and Compatibility

- Status: active
- Last reviewed: 2026-08-05
- Scope: Betaflight Blackbox framing, writer/viewer compatibility, headers, version routing, and Airframe reader behavior
- Normative decisions: `../MEMORY.md`
- Related implementation: `Airframe/Packages/BlackboxReader/`

## Evidence Matrix

| ID | Claim | Source | Grade | Scope | Airframe impact | Status |
|---|---|---|---|---|---|---|
| BFC-001 | Current writer and viewer use `I`, `P`, `S`, `H`, `G`, and `E` frames; current predictor and encoding IDs match Airframe's decoded raw set. | BF-SRC, BLV | A/B | Current checked revisions | Preserve dynamic schemas and robust resynchronization. | verified |
| BFC-002 | Event payloads do not uniformly carry timestamps; flight-mode payloads are 32-bit current/previous masks. | BF-SRC, BLV | A/B | Current checked revisions | Use latest valid main-frame time as context when payload time is absent. | verified |
| BFC-003 | Current firmware headers have substantial naming drift from legacy/viewer-era catalogs. | BF-SRC, AF-SRC | A | Current audit | Canonicalize aliases without collapsing distinct meanings; preserve unknown headers. | verified |
| BFC-004 | Initial supported baseline is Betaflight 4.4.3 with Blackbox Data version 2; older versions remain best effort until fixtures/goldens exist. | Airframe decision and fixtures | A | Product compatibility | Keep compatibility claims conservative. | verified |
| BFC-005 | Debug-mode integer catalogs are firmware-version-sensitive, including divergent calendar-version tails. | Tagged BF source audit | A | 4.3 through 2026.6 | Route explicitly by firmware family; never allow enum shifts. | verified |
| BFC-006 | Betaflight 2026.6.1 adds optional integer header `ap_position_f` without changing Blackbox Data version 2, frame schemas, predictors, or encodings. | BF-SRC | A | 2026.6.1 | Recognize and preserve the header; no parser-format migration. | verified |
| BFC-007 | `BOXWPCAPTURE` is appended beyond the 32 bits copied from `rcModeActivationMask` into Blackbox slow frames and flight-mode events. | BF-SRC | A | 2026.6.1 | Do not expose `WP CAPTURE` as a logged mode; it is not observable in the current Blackbox payload. | verified |

## Format and Writer Findings

Blackbox fields use per-field predictors and encodings. Corrupt or dropped frames require bounded recovery/resynchronization. Current firmware writer files are `src/main/blackbox/blackbox.c`, `blackbox.h`, `blackbox_encoding.*`, `blackbox_fielddefs.h`, `blackbox_io.*`, and `blackbox_virtual.*`; firmware unit tests are useful behavior references.

Flight-mode events contain current and previous `rcModeActivationMask`, not event time. Betaflight does not encode Acro as a mode bit; it is a display fallback. Firmware-version-specific flag tables matter. GPS schemas may include `GPS_velned`, `GPS_time`, and `GPS_home_epoch`, even when higher viewer layers do not use them.

Betaflight 2026.6.1 adds the MSP box `WP CAPTURE` after the existing late box IDs, but Blackbox still stores and serializes only a `uint32_t` mask. The new box therefore cannot appear in `flightModeFlags` or `FLIGHT_LOG_EVENT_FLIGHTMODE`; the MSP box catalog is not evidence that a mode is present in Blackbox data.

## Header Compatibility Findings

The focused current-writer audit found 235 emitted non-frame names versus Airframe's then-current 195 known names and 16 aliases: 111 direct matches, 3 alias-only matches, 124 writer names unknown to Airframe, and 81 Airframe names absent under those names. Important drift included snake_case forms (`thr_mid`, `thr_expo`, `vbat_scale`, `pid_at_min_throttle`, `pidsum_limit*`), `dyn_idle_min_rpm`, consolidated `vbatcellvoltage`, and modern gyro/D-term/filter/feedforward/RPM/GPS/autopilot settings.

The earlier aliases `currentSensor -> currentMeter` and `d_max -> d_min` were semantically wrong and were removed. Reader now owns canonical recognition and typed semantic derivation. `ReaderInfoRow` keeps display, raw, and typed values separately.

Battery cell count is not logged directly. Firmware auto-detection is effectively `floor(vbatref / vbatmaxcellvoltage) + 1`, capped at 8 unless `force_battery_cell_count` is nonzero. Historical thresholds appear in decivolt- and centivolt-style forms, so Airframe normalizes both.

Other verified semantics:

- `vbatcellvoltage` values are centivolts for display (`340` -> `3.40 V`).
- `motor_idle` is percent times 100; `dyn_idle_min_rpm` is hundreds of RPM (`65` -> 6,500 RPM).
- `looptime` is gyro sample period; PID loop rate also includes `pid_process_denom`.
- Betaflight 4.4+ motor protocol raw 7/8/9 means DSHOT600/PROSHOT1000/DISABLED.
- `serialrx_provider` raw 0 changes meaning at 4.5; raw 9 is CRSF.
- Current `env`, and fallback `status`, can supply runtime identity absent from Blackbox headers.
- `ap_position_f` is an optional 2026.6.1 Autopilot position feedforward header stored as an integer; older logs legitimately omit it.
- GPS altitude is decimeters, `baroAlt` centimeters, GPS speed centimeters per second, and coordinates degrees times 10,000,000.
- A combined-IMU accelerometer name may cautiously imply gyro identity only for known combined parts; `AUTO`, `NONE`, and standalone accelerometers do not.

## Version Routing

Debug catalogs route `<4.4` to 4.3, 4.4.x to 4.4, 4.5.x to 4.5, legacy 4.6.x to the inspected development catalog, 2025.12.x to 2025.12, and 2026.6.x or later to 2026.6. Missing versions intentionally use newest-known 2026.6; unmapped values remain unknown. In 2025.12, values 96–99 end with AUTOPILOT_POSITION/CHIRP/FLASH_TEST_PRBS/MAVLINK_TELEMETRY; the final 2026.6.1 catalog assigns a different tail through 101 (`AUTOPILOT_STOP`). Unreleased 2026.12-alpha appends `PITOT` at 102; it is not part of stable 2026.6 compatibility.

### CHIRP debug payload compatibility

- `debug_mode = CHIRP` alone does not prove that a log contains the complete modern CHIRP analysis payload. Betaflight `2025.12.2` commit `79065c96b` writes only `debug[0] = phase * 5000` in `DEBUG_CHIRP`; it does not write the later axis, instantaneous-frequency, and excitation channels.
- In the later layout inspected in current firmware, `debug[1]` is the active axis (`0` Roll, `1` Pitch, `2` Yaw, `-1` inactive), `debug[2] / 10` is frequency in Hz, and `debug[3] / 1000` is raw excitation. Availability checks must verify meaningful recorded values and firmware capability, not merely field-schema presence: Blackbox schemas can contain `debug[0...7]` while unwritten channels remain zero.
- CHIRP activation is independently observable as the firmware-verified `BOXCHIRP` flight mode. This delimits the excitation even when the complete CHIRP debug payload is unavailable, but it cannot by itself provide reliable per-axis/frequency/excitation metadata for modern frequency-response analysis. Airframe's existing Wiener-deconvolution Step Response does not need to exclude these regions: Betaflight logs the CHIRP-inclusive `pidRuntime.previousPidSetpoint[]`, and the estimator accepts arbitrary sufficiently exciting input rather than requiring literal step events.
- Real document evidence on 2026-08-02: `Tuning.airframe` from craft Nilpferd contains Betaflight `2025.12.2 (79065c96b)` CHIRP flights with raw debug mode `97`; event decoding positively identifies CHIRP intervals, while `debug[1...3]` remain zero as predicted by that firmware source.

## Source Register

| Source ID | Title | Author/project | Version/date | URL or local path | Accessed | Notes |
|---|---|---|---|---|---|---|
| BF-DOC | Blackbox logging and internals | Betaflight | current docs | https://betaflight.com/docs/wiki/guides/current/Black-Box-logging-and-usage and https://betaflight.com/docs/development/Blackbox-Internals | 2026-08-01 | Official format context |
| BF-SRC | Blackbox writer | Betaflight | tag `2026.6.1`, commit `6dbc4218fd6bc33bf16ea32c670304d4f89321d5` | `betaflight/src/main/blackbox/` and `src/main/fc/rc_modes.h` | 2026-08-05 | Primary stable writer and mode-layout evidence |
| BLV | Official viewer parser/model | Betaflight | commit `1222587e162fd2c881ee2ea3d74ec91c2397891d` | `blackbox-log-viewer/src/flightlog_parser.js`, `flightlog.js`, and field definitions | 2026-08-05 | Viewer code unchanged from prior pin; intervening commits are workflow/lockfile-only |
| BFT | Blackbox tools | Betaflight | current upstream | https://github.com/betaflight/blackbox-tools | 2026-08-01 | Candidate golden-output oracle |
| AF-SRC | Airframe Reader | Airframe | working tree observed 2026-08-01 | `Airframe/Packages/BlackboxReader/` | 2026-08-01 | Current product behavior |
