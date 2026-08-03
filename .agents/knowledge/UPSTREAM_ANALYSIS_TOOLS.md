# Upstream Analysis Tools

## Betaflight CHIRP / Autotune

- Spectrogram contract verified against current Configurator `master` and pinned commit `14a050b7b57b4addadc209e5b67b3cfd9fdef943` on 2026-08-03: one-axis gyro output, 256-sample Hann STFT, 75% overlap / 64-sample hop, 129 one-sided bins, cell power `10*log10(re²+im²+1e-20)`, time on X, frequency on Y, and display capped at `min(500 Hz, Nyquist)`. Configurator presentation uses per-axis min/max dB normalization, D3 Inferno, opaque pixelated rendering, separate axes per canvas, no image smoothing, and start/end-frequency markers. Airframe retains a different monotonic palette and shared multi-axis timeline; its multi-run extension averages linear power before dB conversion.
- The 2026 Configurator Autotune path segments CHIRP recordings, uses logged setpoint as input and gyro as output, estimates a Welch transfer function, and derives magnitude, phase, coherence, sensitivity, and a step response. Its step response is not event-derived: it inverse-transforms the measured closed-loop transfer function into an impulse response and cumulatively integrates that impulse response.
- The Unmanned Tech/UAV Tech review `Betaflight Autotune review, promising maths, reckless buttons` treats measurement graphs as the current value and automatic PID application as unsafe. It recommends validating a distinct spectrogram sweep and high coherence before interpretation, using Acro rather than Angle to reduce cross-axis contamination, and deliberately preparing firmware, CHIRP mode, Blackbox debug mode, and tuning settings before flight. The article does not identify an exact tested firmware commit, so implementation compatibility must remain source- and fixture-verified.
- Product interpretation: Airframe's existing Wiener-deconvolution Step Response already derives a step response from arbitrary logged setpoint/gyro excitation, including CHIRP. The Configurator derives a conceptually equivalent curve from its measured frequency-domain transfer function. Compare both outputs on complete modern CHIRP payloads before introducing a second user-visible curve. PID recommendations remain backlog until neutral CHIRP measurements are validated.

## Real Nilpferd tuning document observation (2026-08-02)

- The user-supplied regular-file `Tuning.airframe` contains eleven embedded logs. Named `Stock` uses simplified PID sliders at 1.0 and includes three positively observed CHIRP activations; named `Wobble` uses the user's 1.20 master / 1.30 D / 1.05 PI tune and contains no CHIRP activation.
- Betaflight PID UI compatibility matrix verified 2026-08-03 against the local firmware maintenance branches and pinned Configurator `PidSubTab.vue`: BF 4.3 uses MSP API 1.44, BF 4.4 uses 1.45, BF 4.5 uses 1.46, BF 2025.12 uses 1.47, and BF 2026.6 uses 1.48. API 1.45 adds advanced TPA mode and changes Anti Gravity gain display scaling from raw/1000 to raw/10; API 1.47 corrects the historically swapped D/D Max PID-table labels; API 1.48 removes Absolute Control. The Blackbox header field set also evolves by version, so per-log settings presentation must be presence-driven and must not synthesize missing Configurator values.
- The current Configurator PID UI order is: PID Tuning Sliders; Basic/Acro P, I, version-correct D/D Max, Feedforward; optional Angle/Horizon; then Feedforward, TPA, I Term Relax, Anti Gravity, Dynamic Damping, Throttle and Motor Settings, and Miscellaneous Settings. Some UI values require presentation transforms: simplified sliders raw/100, Feedforward Transition raw/100, Feedforward Averaging enum 0...3 = OFF/2/3/4 Point, I Term Relax and Type enums, TPA Mode 0/1 = PD/D, and Anti Gravity gain version-dependent scaling.
- Over each log's persisted Step Response range, the existing calculator produced plausible accepted-window results. `Stock` peak values were Roll 1.342, Pitch 1.196, Yaw 1.101; `Wobble` produced Roll 1.116, Pitch 1.150, Yaw 1.081. Two additional CHIRP comparison logs produced approximately `(1.036, 1.198, 1.020)` and `(0.964, 1.065, 1.003)`.
- Isolation by CHIRP flight-mode interval confirmed that the active axis produces qualifying logged-setpoint windows and a plausible Wiener-deconvolution Step Response. The three `Stock` activations had inferred active axes Pitch, Yaw, and Roll because the firmware's static axis counter had already advanced before the logged sequence; their active-axis results were approximately Pitch `(peak 0.975, latency 5.5 ms, 12 accepted windows)`, Yaw `(1.189, 10.0 ms, 8)`, and Roll `(1.139, 9.0 ms, 8)`. Exact firmware source confirms CHIRP is added to `currentPidSetpoint`, copied to `pidRuntime.previousPidSetpoint`, and then logged as `setpoint[]`. The legacy debug payload still prevents the modern Configurator frequency-response path, but it does not invalidate Airframe's existing Step Response.

- Status: active
- Last reviewed: 2026-08-01
- Scope: analysis/reference tools inspected to inform an independent Swift implementation
- Normative decisions: `../MEMORY.md`
- Related implementation: Airframe Reader, BlackboxAnalysis, graph, map, spectrum, and step-response packages

## Evidence Matrix

| ID | Claim | Source | Grade | Scope | Airframe impact | Status |
|---|---|---|---|---|---|---|
| UAT-001 | Blackbox Explorer is a Vite/Vue PWA; parser/model code is mostly plain JavaScript while rendering relies on browser Canvas/DOM/video/Leaflet/Three.js. | BLV | B | Inspected revision | Port behavior independently, not browser architecture. | verified |
| UAT-002 | Explorer provides frequency, frequency-vs-throttle/RPM, Welch PSD variants, and PID-error-vs-setpoint analyses. | BLV | B | Inspected revision | Existing and deferred Airframe modes have a behavioral reference. | verified |
| UAT-003 | PIDtoolbox free source exposes spectrum, delay, step-response, eRPM, and related algorithms; Pro MATLAB files are encrypted. | PTB | B | v0.23-era mirror | Cite free source precisely and do not claim Pro equivalence. | verified |

## Blackbox Explorer Map

Important files include `flightlog_parser.js`, `decoders.js`, `datastream.js`, `flightlog_index.js`, `flightlog.js`, `flightlog_fielddefs.js`, `flightlog_fields_presenter.js`, `graph_config.js`, `grapher.js`, `graph_spectrum_calc.js`, `graph_map.js`, `craft_3d.js`, and `flightlog_video_renderer.js`. At the original sizing pass, several core files were roughly 1,300–3,100 lines, reinforcing the need for separated native packages rather than direct structural translation.

Spectrum findings retained from the 2026-07-15 audit:

- Welch PSD defaults to 512-point segments, 75% overlap, Hanning scaling `1/(rate*sum(win^2))`, and `10*log10` with a `1e-7` floor (`-70 dB`).
- PSD heatmaps expose roughly `-40…+10 dB` defaults and a low-level clamp.
- Dynamic LPF curve is `min + (max-min) * (t*(1-t)*expo + t)`.
- Frequency display intensity is absolute rather than max-normalized.
- Throttle percent derives from `rcCommands[3]` and configured/default min/max throttle.
- The viewer parses RPM-filter headers but does not draw the PIDtoolbox-Pro-style harmonic distribution overlay.

RPM-notch source research found no open PIDtoolbox Pro math. Firmware provides the authoritative eRPM/harmonic center and weight semantics. Airframe's empirical distribution/CDF-like overlay remains an Airframe-derived interpretation validated visually, not an upstream algorithm claim. Detailed spectrum conclusions live in [Spectrum Tuning Guides](SPECTRUM_TUNING_GUIDES.md).

## Related Parsers

Potential behavioral references include Rust `blackbox_log`, Rust `bbl_parser`, TypeScript/WASM `blackbox-log-ts`, and Python `orangebox`. They have not been deeply evaluated and are candidates for oracles, not dependencies.

## Source Register

| Source ID | Title | Author/project | Version/date | URL or local path | Accessed | Notes |
|---|---|---|---|---|---|---|
| BLV | Blackbox Explorer | Betaflight | commit `a039b74492cdbaca6f94852a7958df1c2dc064b1`, observed 2026.6.0 | `blackbox-log-viewer/src/` | 2026-08-01 | Read-only reference |
| PTB | PIDtoolbox free source | PIDtoolbox | commit `1e12abb23188183f0f21998a6a89af3719ded22a` | `PIDtoolbox/` | 2026-08-01 | Algorithmic ancestor; Pro source unavailable |
| BFT | Blackbox tools | Betaflight | current upstream | https://github.com/betaflight/blackbox-tools | 2026-08-01 | Candidate golden oracle |
| RUST1 | blackbox_log | community | current listing | https://docs.rs/blackbox-log/latest/blackbox_log/ | 2026-08-01 | Not deeply evaluated |
| RUST2 | bbl_parser | community | current listing | https://docs.rs/bbl_parser | 2026-08-01 | Not deeply evaluated |
