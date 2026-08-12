# Blackbox Format and Compatibility

- Status: active
- Last reviewed: 2026-08-07
- Scope: Betaflight Blackbox framing, writer/viewer compatibility, headers, version routing, and Airframe reader behavior
- Normative decisions: `../.agents/MEMORY.md`
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
| BFC-008 | A physical FC can write disarmed Blackbox logs without an attached ESC: `blackbox_mode = ALWAYS` starts logging whenever the logger is stopped, while `MOTOR_TEST` starts from non-disarm `motor_disarmed[]` command values and does not require ESC feedback. | BF-SRC | A | 2026.6.1 | Hardware-generated parser fixtures can be captured from a USB-powered FC; motor/eRPM response data remains unavailable without the corresponding hardware feedback. | verified |
| BFC-009 | SITL includes `USE_BLACKBOX_VIRTUAL`; the virtual backend writes sequential `LOGnnnnn.BFL` files in the process working directory. | BF-SRC, BF-SITL-DOC | A/B | 2026.6.1 | SITL is a hardware-free source of firmware-generated logs, with simulated signals determined by the connected bridge/model. | verified |
| BFC-010 | A preallocated multi-log FlashFS file can contain valid logs around one header truncated at an erase-block boundary; the observed 8 MiB source had four markers, one header cut at exactly 1 MiB, and three readable logs. | Physical FC source, AF-SRC | A | Betaflight 4.5.5 and 2025.12.5 source on 2026-08-07 | Isolate marker-delimited candidates during import, retain surrounding valid logs and original candidate indices, and report the skipped candidate instead of rejecting the whole source. | verified |

## Format and Writer Findings

Blackbox fields use per-field predictors and encodings. Corrupt or dropped frames require bounded recovery/resynchronization. Current firmware writer files are `src/main/blackbox/blackbox.c`, `blackbox.h`, `blackbox_encoding.*`, `blackbox_fielddefs.h`, `blackbox_io.*`, and `blackbox_virtual.*`; firmware unit tests are useful behavior references.

Flight-mode events contain current and previous `rcModeActivationMask`, not event time. Betaflight does not encode Acro as a mode bit; it is a display fallback. Firmware-version-specific flag tables matter. GPS schemas may include `GPS_velned`, `GPS_time`, and `GPS_home_epoch`, even when higher viewer layers do not use them.

Betaflight 2026.6.1 adds the MSP box `WP CAPTURE` after the existing late box IDs, but Blackbox still stores and serializes only a `uint32_t` mask. The new box therefore cannot appear in `flightModeFlags` or `FLIGHT_LOG_EVENT_FLIGHTMODE`; the MSP box catalog is not evidence that a mode is present in Blackbox data.

### Hardware-free and ESC-free log generation

The current firmware exposes three Blackbox modes through the CLI: `NORMAL`, `MOTOR_TEST`, and `ALWAYS`. On a physical FC, `set blackbox_mode = ALWAYS` causes the Blackbox state machine to open a log whenever it is stopped, including while disarmed and powered only over USB. It records the real on-board sensor and controller state, but fields that depend on absent hardware, such as bidirectional DShot RPM telemetry, cannot contain real feedback.

`set blackbox_mode = MOTOR_TEST` is the narrower bench-test path. `MSP_SET_MOTOR` writes commanded values into `motor_disarmed[]`; `areMotorsRunning()` compares those values with the configured disarm output; and the Blackbox state machine starts logging while the FC is disarmed. No ESC acknowledgement or telemetry participates in that decision. Logging continues for five seconds after all commands return to the disarm value. A serial Blackbox device cannot use the same serial port as MSP in this mode.

For fully hardware-free integration, the SITL target defines `USE_BLACKBOX_VIRTUAL`. Its backend creates sequential `LOG00001.BFL`-style files in the SITL process working directory. SITL can receive virtual IMU/GPS state from Gazebo or another supported bridge and therefore exercises more of the real firmware pipeline than the focused Blackbox unit tests. The unit tests directly cover encoding and logging cadence, but are not themselves a complete flight-log generator.

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
| BF-SRC | Blackbox writer | Betaflight | tag `2026.6.1`, commit `6dbc4218fd6bc33bf16ea32c670304d4f89321d5` | `upstreams/betaflight/src/main/blackbox/` and `src/main/fc/rc_modes.h` | 2026-08-05 | Primary stable writer and mode-layout evidence |
| BF-SITL-DOC | SITL target README | Betaflight | commit `6dbc4218fd6bc33bf16ea32c670304d4f89321d5` | `upstreams/betaflight/src/platform/SIMULATOR/target/SITL/README.md` | 2026-08-06 | Official hardware-free simulator setup; implementation details are verified in BF-SRC. |
| BLV | Official viewer parser/model | Betaflight | commit `1222587e162fd2c881ee2ea3d74ec91c2397891d` | `upstreams/blackbox-log-viewer/src/flightlog_parser.js`, `flightlog.js`, and field definitions | 2026-08-05 | Viewer code unchanged from prior pin; intervening commits are workflow/lockfile-only |
| BFT | Blackbox tools | Betaflight | current upstream | https://github.com/betaflight/blackbox-tools | 2026-08-01 | Candidate golden-output oracle |
| AF-SRC | Airframe Reader | Airframe | working tree observed 2026-08-01 | `Airframe/Packages/BlackboxReader/` | 2026-08-01 | Current product behavior |
