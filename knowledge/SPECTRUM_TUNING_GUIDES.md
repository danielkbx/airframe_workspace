# Spectrum Tuning Guides

- Status: implemented as an explicitly heuristic guide layer; not validated across craft classes
- Last reviewed: 2026-08-05
- Scope: filter delay, spectrum interpretation, setup-specific visual guides, measured motor bands, and cautious user-facing terminology
- Normative decisions: `../.agents/MEMORY.md` after implementation approval
- Related implementation: `Airframe/Packages/BlackboxAnalysis/Sources/BlackboxAnalysis/Spectrum/` and `Airframe/Packages/AirframeUI/Sources/AirframeUI/Spectrum/`

## Executive Essence

Filtering attenuates vibration and motor noise but adds phase delay. Lower delay can improve response and propwash handling, while insufficient filtering can expose D-term to high-frequency noise and heat motors. The often-repeated `50 Hz`, `-30 dB`, and `-10 dB` figures are useful comparison references in the measurement context from which they came; they are not universal safety limits. Propeller diameter, motor speed, KV, voltage, mass, frame construction, propeller geometry, sampling, windowing, and PSD normalization all affect what a spectrum looks like.

Airframe presents these guides only in the standard frequency-line view. Frequency-vs-Throttle and Frequency-vs-RPM heatmaps already encode a second variable through position and intensity, so the guide regions, P90 lines, and motor-density layer add limited interpretive value and unnecessary visual competition there.

Airframe should therefore present setup profiles as manually selected, explicitly heuristic context. Actual eRPM-derived motor bands and configured filters are stronger evidence than a propeller-size profile. The UI must not turn these references into a pass/fail verdict.

## Evidence Matrix

| ID | Claim | Source | Grade | Scope | Airframe impact | Status |
|---|---|---|---|---|---|---|
| STG-001 | Every filter adds delay; greater delay can worsen propwash oscillation tendency and dull handling. | BF40, OL1, BF-FS, CR45-FILTER | B/C | General tuning principle | Explain the attenuation/delay tradeoff; never imply “more filtering is always better.” | verified |
| STG-002 | Oscar Liang describes approximate 5-inch-oriented regions below 20 Hz, 20–100 Hz, 100–250 Hz, and above 250 Hz for motion/control-resonance/motor-noise interpretation. | OL1 | C | Secondary tuning guidance | Treat these as contextual labels, not causal classification. | partially verified |
| STG-003 | The cited workflow uses a gyro reference around `-30 dB` above about `50 Hz` and a D-term reference around `-10 dB`. | OL1 | C | PIDtoolbox-style plots | Render only as named references tied to comparable analysis; no traffic-light status. | partially verified |
| STG-004 | Typical maximum motor frequency varies with prop size: about 600–650 Hz for 3–4-inch, 450–500 Hz for typical 5-inch, and 300–350 Hz for larger quads. | BF40 | B | Historical Betaflight 4.0 guidance | A fixed 5-inch frequency guide is unsuitable for every craft. | verified |
| STG-005 | D-term is especially sensitive to high-frequency noise and excessive D/noise can heat motors. | BF-PID, BF-FS, CR45-FILTER | B/C | General tuning guidance | Keep gyro and D-term measurements distinct. | verified |
| STG-006 | Bidirectional DShot reports eRPM and Betaflight converts it using motor pole count; RPM filtering targets per-motor harmonics. | BF-RPM, BF-SRC | A/B | Betaflight RPM filtering | Prefer measured motor bands over static prop-size estimates and surface missing/wrong pole-count uncertainty. | verified |
| STG-007 | Firmware motor-frequency conversion used by current Airframe research is `motorHz = eRPMLogValue * 3.333 / motorPoles`, with notch centers at integer harmonics and loop-rate ceiling. | BF-SRC | A | Inspected local firmware revision | Reuse the existing RPM-notch semantic path rather than inventing a second conversion. | verified |
| STG-008 | PIDtoolbox v0.23 estimates gyro/D-term delay on roll with smoothing and bounded `finddelay`; modern Blackbox logs can expose `gyroUnfilt` independently of debug mode. | PTB, BF-SRC | A/B | Inspected source revisions | Airframe may compute delay independently, using `gyroUnfilt` where available, but must document algorithm differences. | verified |
| STG-009 | Airframe currently computes a periodogram-like dB spectrum, has filter-delay and RPM-notch analyses, and renders stacked frequency and heatmap canvases. | AF-SRC | A | Current Airframe source | Guide profiles are an interpretation/render layer, not a new FFT. | verified |
| STG-010 | Scaling every 5-inch guide frequency inversely with representative propeller diameter is a useful model. | Airframe proposal | D | Proposed UI heuristic | Do not ship as factual physics until real-log validation succeeds. | heuristic |
| STG-011 | A narrow peak nearly constant across throttle may be a structural resonance, whereas throttle-dependent ridges are consistent with motor harmonics. | BLV/PTB behavior plus Airframe inference | B/D | Spectrum-vs-throttle interpretation | Label candidates `Possible Resonance`; never assert the mechanical cause. | partially verified |
| STG-012 | Mechanical resonance is not confined to a predictable prop-size frequency band. Natural frequencies vary by frame stiffness, mass, props, mounting, loose or cracked parts, antennas, and other structures; stiff frames may resonate at high frequencies. | BF31, BF-RPM, UAVT, CR45-FILTER | B/C | All craft classes | Do not label broad frequency regions as if they exclude resonance or establish a cause. | verified |
| STG-013 | Motor-related noise is identified more reliably by throttle/RPM-dependent ridges and eRPM harmonics than by a fixed lower frequency boundary. Bearings, wind, turbulence, frame, and prop resonances can coexist outside or inside the same band. | BF-RPM, OL1, CR45-FILTER | B/C | Logs with suitable heatmap/eRPM data | Prefer measured eRPM overlays and shape/behavior evidence over a categorical `Motor / Propeller Noise` region. | verified |
| STG-014 | RPM-filter crossfading reduces low-RPM filtering where the tracked motor frequency is below the useful notch range; harmonic dimming can reduce filtering on weak harmonics. Reducing weights is justified only after checking downstream residual noise. | BF45, CR45-FILTER | B/C | Betaflight 4.5 RPM-filter tuning | Use measured harmonic occupancy and residual D/motor noise; never infer weights from blade count alone. | verified |
| STG-015 | A raw-gyro spectrum can understate the practical effect of residual motor noise because D amplifies high-frequency content; BF 4.5 guidance recommends checking filtered gyro and downstream D-term or motor spectra. | BF45, CR45-FILTER | B/C | Logs with comparable downstream signals | Prefer multi-stage evidence over declaring a filter tune complete from one raw spectrum. | verified |
| STG-016 | Rosser's compared “Easy” and “AOS” BF 4.5 filter configurations demonstrate a tradeoff among phase delay, useful-signal attenuation, quiet-zone transmission, and motor-noise rejection; neither curve is a universal optimum. | CR45-FILTER | C | Illustrated BF 4.5 configurations | Use the comparison as explanatory context only; do not expose either configuration as an Airframe default. | verified |
| STG-017 | The Rosser deck labels content through roughly `90 Hz` as useful flight movement/propwash for its example and separates a quiet zone from motor noise. Those boundaries depend on craft and analysis context. | CR45-FILTER | C | Illustrated example | Do not turn `90 Hz` or the depicted zones into global classification thresholds. | heuristic |

## Source Essence

### Oscar Liang

The article explains filtering as a tradeoff: filters remove noise but introduce delay, and excessive delay can make the controller react later. It recommends inspecting sub-100 Hz content for vibration, oscillation, and propwash behavior and provides practical spectrum regions commonly used around 5-inch tuning. Its `-30 dB` gyro, `-10 dB` D-term, and approximately `50 Hz` analysis references are tuning heuristics presented in a particular PIDtoolbox/Blackbox workflow. They must not be generalized into universal safety thresholds.

### Betaflight documentation and firmware

Betaflight documents that the relevant motor-frequency range shifts with craft and propeller size. Its historical 4.0 notes place typical maximum motor frequency around 450–500 Hz for 5-inch, higher for smaller props and lower for larger props. Current tuning material emphasizes the phase-delay cost of filtering and the special risk of noisy D-term. RPM filtering uses actual per-motor telemetry and harmonics, so a log-derived motor band is more informative than a static inch category when eRPM and the correct motor pole count are available.

### PIDtoolbox

The inspected free PIDtoolbox source estimates filter delay with smoothed signals and a bounded correlation delay, separately presenting gyro, D-term, and total delay. PIDtoolbox Pro is compiled/encrypted and its precise implementation cannot be audited. Airframe must call out any algorithmic difference rather than claiming exact PIDtoolbox equivalence.

### Airframe

Airframe already has native spectrum results in dB, filter-delay estimation, RPM-notch data, and frequency/heatmap renderers. The proposed guides consume those results. They do not alter the parser, stored Blackbox data, or FFT calculation.

### UAV Tech

UAV Tech's canonical tuning hub presents PID tuning as a general control-loop process across firmware and craft classes, recommends presets as a starting point, and separates general principles from class-specific practice such as Whoops and 6–10-inch craft. Its linked PID Tuning Principles guide treats RPM filtering as the tracker for motor-frequency peaks and leaves the Dynamic Notch to find frame resonances and other noise peaks, explicitly including vibrating antennas and cracked frames. This supports behavior-based identification and individualized log analysis, not fixed causal frequency regions.

### Chris Rosser BF 4.5

Chris Rosser's expert BF 4.5 filter deck uses frequency-vs-throttle plots to distinguish motor fundamentals, harmonics, and more stationary resonance candidates. It explains RPM crossfading, harmonic dimming, Dynamic Notch selection, and low-pass filtering as targeted ways to reduce noise while retaining useful response. Its filter-comparison plots make the tradeoff concrete: a configuration can transmit less motor noise while transmitting more content in another band, and slightly lower phase delay is not free.

The deck's blade-count weight examples, Dynamic Notch bounds, `90 Hz` useful-signal region, “Easy” tune, and AOS tune remain BF 4.5 expert examples. Airframe should use measured harmonics and downstream residual noise to explain a log, not prescribe those settings from craft labels alone. Broader controller interpretation from Rosser and UAV Tech lives in [PID Tuning Principles](PID_TUNING_PRINCIPLES.md).

## Uncertainties and Non-Claims

- Propeller diameter is not reliably encoded in a Blackbox log; profile selection is manual.
- Diameter alone does not determine useful bands. KV, voltage, prop pitch/blade count, frame stiffness, mass, motor condition, mounting, and firmware settings matter.
- Absolute dB values depend on signal units, normalization, sample rate, windowing, and estimator. Comparisons are meaningful only when analysis semantics are compatible.
- `50 Hz` is neither a universal boundary between flight motion and noise nor a universal lower cutoff.
- A stationary spectral feature does not prove frame resonance.
- Resonance can occur above any profile's nominal resonance boundary; a vibrating antenna, loose part, cracked frame, stiff structure, propeller, or mounting can produce high-frequency fixed peaks.
- `Possible Resonance` and `Motor / Propeller Noise` must not be presented as mutually exclusive causal regions. The current profile regions are educational heuristics only and their causal labels should be removed or replaced with neutral low/mid/high-frequency wording.
- A quiet spectrum does not prove a safe tune, and a reference exceedance does not prove a bad build.
- Historical Betaflight 4.0 frequency examples are useful context, not current configuration defaults.
- Betaflight 4.5 commands, filter types, crossfade/dimming behavior, and slider workflows require version checks before application to later firmware.
- Rosser's `90 Hz` useful-signal boundary and depicted quiet/motor zones describe his example plots, not universal physical regions.

## Airframe Interpretation

- Static prop-size profiles are an implemented Grade `D` educational layer. They are not filter recommendations and do not produce pass/fail or safety verdicts.
- Actual eRPM-derived harmonic occupancy, configured filter overlays, filter delay, and compatible per-signal measurements are stronger evidence than a selected profile.
- The current profile UI renders only neutral motion/control context plus measured evidence; causal `Possible Resonance` and `Motor / Propeller Noise` regions are deliberately not shown.
- Automatic resonance detection remains unimplemented until representative logs validate a conservative behavior-based detector.
- Future Filter Review and Filter Score work is specified in [the active roadmap](../.agents/PLAN.md#measure-5-spectrum-filter-review). This topic supplies evidence and limitations; product interfaces and execution order do not live here.

## Validation Needs

- Validate the existing Grade `D` profile scaling across representative craft classes before strengthening any wording.
- Vary KV, voltage, blade count/pitch, frame/mass, and filter configuration where practical.
- Compare only spectra with compatible units, normalization, windowing, sample rate, and estimator semantics.
- Validate downstream gyro, D-term, and motor-output evidence before grading harmonic-weight or filter-efficiency claims.

## Source Register

| Source ID | Title | Author/project | Version/date | URL or local path | Accessed | Notes |
|---|---|---|---|---|---|---|
| OL1 | How to Tune FPV Drone Filters & PID with Blackbox | Oscar Liang | page current when accessed | https://oscarliang.com/pid-filter-tuning-blackbox/ | 2026-08-01 | Secondary practical guide; values are contextual heuristics |
| BF40 | Betaflight 4.0 Tuning Notes | Betaflight | historical 4.0 documentation | https://betaflight.com/docs/wiki/tuning/4-0-Tuning-Notes | 2026-08-01 | Source for prop-size/max-motor-frequency examples and delay tradeoff |
| BF-PID | PID Tuning Guide | Betaflight | current docs | https://betaflight.com/docs/wiki/guides/current/PID-Tuning-Guide | 2026-08-01 | D-term/noise and tuning-risk context |
| BF-FS | Freestyle Tuning Principles | Betaflight | current docs | https://betaflight.com/docs/wiki/guides/current/Freestyle-Tuning-Principles | 2026-08-01 | Filter/phase-delay guidance |
| BF-RPM | DShot RPM Filtering | Betaflight | current docs | https://betaflight.com/docs/wiki/guides/current/DSHOT-RPM-Filtering | 2026-08-01 | eRPM, motor poles, and harmonic RPM filtering |
| BF-CLI | Command Line Interface | Betaflight | current docs | https://betaflight.com/docs/wiki/guides/current/Cli | 2026-08-01 | Filter/motor settings vocabulary |
| BF-SRC | RPM filter and DShot source | Betaflight | tag `2026.6.1`, commit `6dbc4218fd6bc33bf16ea32c670304d4f89321d5` | `upstreams/betaflight/src/main/flight/rpm_filter.c`; `upstreams/betaflight/src/main/drivers/dshot.c`; related headers | 2026-08-05 | Primary local implementation evidence |
| PTB | PIDtoolbox spectrum/delay implementation | PIDtoolbox | commit `1e12abb23188183f0f21998a6a89af3719ded22a` | `upstreams/PIDtoolbox/PTspecUIcontrol.m` and related spectrum code | 2026-08-01 | Free source; Pro implementation unavailable |
| BLV | Blackbox Explorer spectrum implementation | Betaflight Blackbox Explorer | commit `1222587e162fd2c881ee2ea3d74ec91c2397891d` | `upstreams/blackbox-log-viewer/src/graph_spectrum_calc.js`; related plot/UI files | 2026-08-05 | Reference behavior, not copied architecture; functional source unchanged from prior pin |
| AF-SRC | Airframe native spectrum implementation | Airframe | working tree observed 2026-08-01 | `Airframe/Packages/BlackboxAnalysis/Sources/BlackboxAnalysis/Spectrum/`; `Airframe/Packages/AirframeUI/Sources/AirframeUI/Spectrum/` | 2026-08-01 | Primary evidence for current Airframe behavior |
| BF31 | Gyro and Dterm Filtering Recommendations 3.1 | Betaflight | archived 3.1 guidance | https://betaflight.com/docs/wiki/guides/archive/Gyro-And-Dterm-Filtering-Recommendations-3-1 | 2026-08-02 | Explicitly says resonance points cannot be predicted and vary per frame and prop |
| UAVT | Tuning hub and PID Tuning Principles | UAV Tech | October 2020 guide; site and PDF rechecked 2026-08-05 | https://theuavtech.com/tuning/ and https://theuavtech.com/wp-content/uploads/2020/10/UAV-Tech-PID-Tuning-Principles.pdf | 2026-08-05 | Canonical expert hub; distinguishes general principles and craft-specific practice, and lists antennas, cracked frames, and other peaks as Dynamic Notch targets |
| BF45 | Betaflight 4.5 Release Notes | Betaflight | 4.5 release documentation | https://betaflight.com/docs/wiki/release/Betaflight-4-5-Release-Notes | 2026-08-05 | Official context for RPM harmonic weights, residual downstream noise, and version scope |
| CR45-FILTER | BF 4.5 Tuning Guide Part 1: Filters | Chris Rosser | created 2024-03-20 | `sources/chris-rosser/BF-4.5-Filter-Tuning.pdf`; https://www.youtube.com/watch?v=E3s5XYk3M74 | 2026-08-05 | Expert secondary source; private archived Patreon deck, public companion video, integrity data in source README |
