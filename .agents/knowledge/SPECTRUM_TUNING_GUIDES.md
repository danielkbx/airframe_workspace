# Spectrum Tuning Guides

- Status: implemented as an explicitly heuristic guide layer; not validated across craft classes
- Last reviewed: 2026-08-01
- Scope: filter delay, spectrum interpretation, setup-specific visual guides, measured motor bands, and cautious user-facing terminology
- Normative decisions: `.agents/MEMORY.md` after implementation approval
- Related implementation: `Airframe/Packages/BlackboxAnalysis/Sources/BlackboxAnalysis/Spectrum/` and `Airframe/Packages/AirframeUI/Sources/AirframeUI/Spectrum/`

## Executive Essence

Filtering attenuates vibration and motor noise but adds phase delay. Lower delay can improve response and propwash handling, while insufficient filtering can expose D-term to high-frequency noise and heat motors. The often-repeated `50 Hz`, `-30 dB`, and `-10 dB` figures are useful comparison references in the measurement context from which they came; they are not universal safety limits. Propeller diameter, motor speed, KV, voltage, mass, frame construction, propeller geometry, sampling, windowing, and PSD normalization all affect what a spectrum looks like.

Airframe presents these guides only in the standard frequency-line view. Frequency-vs-Throttle and Frequency-vs-RPM heatmaps already encode a second variable through position and intensity, so the guide regions, P90 lines, and motor-density layer add limited interpretive value and unnecessary visual competition there.

Airframe should therefore present setup profiles as manually selected, explicitly heuristic context. Actual eRPM-derived motor bands and configured filters are stronger evidence than a propeller-size profile. The UI must not turn these references into a pass/fail verdict.

## Evidence Matrix

| ID | Claim | Source | Grade | Scope | Airframe impact | Status |
|---|---|---|---|---|---|---|
| STG-001 | Every filter adds delay; greater delay can worsen propwash oscillation tendency and dull handling. | BF40, OL1, BF-FS | B/C | General tuning principle | Explain the attenuation/delay tradeoff; never imply “more filtering is always better.” | verified |
| STG-002 | Oscar Liang describes approximate 5-inch-oriented regions below 20 Hz, 20–100 Hz, 100–250 Hz, and above 250 Hz for motion/control-resonance/motor-noise interpretation. | OL1 | C | Secondary tuning guidance | Treat these as contextual labels, not causal classification. | partially verified |
| STG-003 | The cited workflow uses a gyro reference around `-30 dB` above about `50 Hz` and a D-term reference around `-10 dB`. | OL1 | C | PIDtoolbox-style plots | Render only as named references tied to comparable analysis; no traffic-light status. | partially verified |
| STG-004 | Typical maximum motor frequency varies with prop size: about 600–650 Hz for 3–4-inch, 450–500 Hz for typical 5-inch, and 300–350 Hz for larger quads. | BF40 | B | Historical Betaflight 4.0 guidance | A fixed 5-inch frequency guide is unsuitable for every craft. | verified for source context |
| STG-005 | D-term is especially sensitive to high-frequency noise and excessive D/noise can heat motors. | BF-PID, BF-FS | B | General tuning guidance | Keep gyro and D-term measurements distinct. | verified |
| STG-006 | Bidirectional DShot reports eRPM and Betaflight converts it using motor pole count; RPM filtering targets per-motor harmonics. | BF-RPM, BF-SRC | A/B | Betaflight RPM filtering | Prefer measured motor bands over static prop-size estimates and surface missing/wrong pole-count uncertainty. | verified |
| STG-007 | Firmware motor-frequency conversion used by current Airframe research is `motorHz = eRPMLogValue * 3.333 / motorPoles`, with notch centers at integer harmonics and loop-rate ceiling. | BF-SRC | A | Inspected local firmware revision | Reuse the existing RPM-notch semantic path rather than inventing a second conversion. | verified |
| STG-008 | PIDtoolbox v0.23 estimates gyro/D-term delay on roll with smoothing and bounded `finddelay`; modern Blackbox logs can expose `gyroUnfilt` independently of debug mode. | PTB, BF-SRC | A/B | Inspected source revisions | Airframe may compute delay independently, using `gyroUnfilt` where available, but must document algorithm differences. | verified |
| STG-009 | Airframe currently computes a periodogram-like dB spectrum, has filter-delay and RPM-notch analyses, and renders stacked frequency and heatmap canvases. | AF-SRC | A | Current Airframe source | Guide profiles are an interpretation/render layer, not a new FFT. | verified |
| STG-010 | Scaling every 5-inch guide frequency inversely with representative propeller diameter is a useful model. | Airframe proposal | D | Proposed UI heuristic | Do not ship as factual physics until real-log validation succeeds. | heuristic |
| STG-011 | A narrow peak nearly constant across throttle may be a structural resonance, whereas throttle-dependent ridges are consistent with motor harmonics. | BLV/PTB behavior plus Airframe inference | B/D | Spectrum-vs-throttle interpretation | Label candidates `Possible Resonance`; never assert the mechanical cause. | partially verified |
| STG-012 | Mechanical resonance is not confined to a predictable prop-size frequency band. Natural frequencies vary by frame stiffness, mass, props, mounting, loose or cracked parts, antennas, and other structures; stiff frames may resonate at high frequencies. | BF31, BF-RPM, UAVT | B/C | All craft classes | Do not label broad frequency regions as if they exclude resonance or establish a cause. | verified |
| STG-013 | Motor-related noise is identified more reliably by throttle/RPM-dependent ridges and eRPM harmonics than by a fixed lower frequency boundary. Bearings, wind, turbulence, frame, and prop resonances can coexist outside or inside the same band. | BF-RPM, OL1 | B/C | Logs with suitable heatmap/eRPM data | Prefer measured eRPM overlays and shape/behavior evidence over a categorical `Motor / Propeller Noise` region. | verified |

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

## Implemented Airframe Concept

### Picker profiles

The Spectrum inspector uses a `Guide Profile` picker:

- `Off`
- `2–2.5″ / Whoop`
- `3–3.5″`
- `4″`
- `5″ Freestyle`
- `6–7″ Long Range`
- `Other / Unknown`

`Other / Unknown` draws no prop-size assumptions. It may still show measured eRPM bands, configured filter guides, neutral noise-floor measurements, and possible resonance candidates.

### Profile content

Known-size profiles provide only a subtle purple `Craft Motion` area, a subtle blue `Control / Prop Wash` area, and gyro/D-term reference lines. Craft Motion is slightly more opaque than Control / Prop Wash, but both remain behind the data. The graph contains no region labels or redundant vertical boundary lines; two-line inspector rows show each name and its exact profile boundary with a matching colored dot. The former `Possible Resonance` and `Motor / Propeller Noise` profile areas are not rendered because their causal labels overstate what a static frequency range can establish. Guides never provide `Safe`, `Required`, `Pass`, or `Fail` values. Actual motor harmonics are drawn as a visually distinct measured layer.

Measured motor harmonics intentionally have no inline text because several motors and harmonics overlap heavily. They form one accent-color horizontal density layer: opacity represents how frequently the combined eRPM harmonics occupied a frequency bin over the selected range. It does not represent vibration magnitude or spectral power. Horizontal Gyro and D-term references display only their dB value; pane content already supplies the signal context.

### Neutral measurements

For compatible traces, Airframe may show the 90th percentile of finite dB bins above the profile's analysis-start frequency. Gyro and D-term remain separate. The result is a measurement with its comparison reference, not a green/yellow/red judgment. No valid bins produce no measurement.

The inspector groups measurements into one cell per signal, titled for example `Gyro P90` or `Gyro Unfiltered P90`. Beneath the title, secondary Roll, Pitch, and Yaw rows show `… dB above … Hz`. These values are calculated from the selected log and range; they are not values supplied by the selected profile. Profile values appear only as plot references.

Every region and P90 data cell provides a trailing info popover organized as `What it is`, `Where it comes from`, and `How to read it`. The source statement stays literal and concise: regions are fixed reference ranges from the selected profile, while P90 is calculated from the signal's log data in the selected timeline range. Interpretation text carries the heuristic caveats and warns that narrow peaks can still exceed the percentile. Only the filtered `Gyro P90` help mentions its `-30 dB` comparison reference; unfiltered Gyro and other signal help must not inherit that signal-specific guidance.

### Possible resonance candidates (not yet implemented)

A future conservative detector may consider a narrow peak only when it is present across enough occupied throttle bins, remains approximately stationary, lies above the motion region, and is clearly separated from measured motor harmonics. It shows at most three candidates per axis and uses the wording `Possible Resonance`. Profile selection must not trigger hidden expensive heatmap computation.

### Document default and log overrides

- With no template, the first concrete selection becomes the document default and applies to every log.
- A later concrete selection on a log initially creates or replaces that log's override.
- After each selection, if no existing log effectively uses the old default, the latest choice becomes the new default; matching overrides are removed and different overrides remain.
- New logs inherit the current document default.
- `Off` is a concrete default or override value.
- The ordinary picker does not expose a separate “remove override” action.
- Reset View Settings clears the default and all overrides.
- Removing a log cleans its override but does not itself promote a new default.

## Implemented Profile Heuristic — Grade D

The following table records the discussed inverse-diameter model. It is not approved physics and must remain visibly heuristic until validated:

```text
scale = 5.0 / representativePropellerDiameter
scaledFrequency = fiveInchReferenceFrequency * scale
```

Values are rounded to readable 5 Hz increments.

| Profile | Representative diameter | Scale | Motion ends | Analyze above | Control/propwash ends | Resonance reference ends | Evidence |
|---|---:|---:|---:|---:|---:|---:|---|
| 2–2.5″ / Whoop | 2.25″ | 2.22 | 45 Hz | 110 Hz | 220 Hz | 555 Hz | Grade D heuristic |
| 3–3.5″ | 3.25″ | 1.54 | 30 Hz | 75 Hz | 155 Hz | 385 Hz | Grade D heuristic |
| 4″ | 4.0″ | 1.25 | 25 Hz | 65 Hz | 125 Hz | 315 Hz | Grade D heuristic |
| 5″ Freestyle | 5.0″ | 1.00 | 20 Hz | 50 Hz | 100 Hz | 250 Hz | Grade C secondary anchor; profile generalization remains Grade D |
| 6–7″ Long Range | 6.5″ | 0.77 | 15 Hz | 40 Hz | 75 Hz | 190 Hz | Grade D heuristic |

The dB comparison references discussed for known profiles are gyro `-30 dB` and D-term `-10 dB`; these retain Grade C and are not rescaled. If cross-size validation fails, the inch profiles may remain context labels while Airframe renders only measured eRPM, configured filters, and carefully detected candidates.

## Validation Matrix

| Craft class | Minimum representative logs | Required signals | Validation target |
|---|---:|---|---|
| 2–2.5″ / Whoop | 3 | Gyro, D-term, throttle; eRPM when available | Compare heuristic zones with actual ridges/noise and motor bands |
| 3–3.5″ | 3 | Same | Same |
| 4″ | 3 | Same | Same |
| 5″ | 5 | Same | Check the Oscar/Betaflight anchor across varied builds |
| 6–7″ | 3 | Same | Check lower motor bands and frame-specific resonances |
| Other / Unknown | 2 | Any useful subset | Confirm no static prop-size claims appear |

Fixtures should vary KV, voltage, blade count/pitch, frame/mass, and filter settings where practical. Until this matrix is satisfied, profile frequency scaling remains `proposed`, not `validated`.

## Source Register

| Source ID | Title | Author/project | Version/date | URL or local path | Accessed | Notes |
|---|---|---|---|---|---|---|
| OL1 | How to Tune FPV Drone Filters & PID with Blackbox | Oscar Liang | page current when accessed | https://oscarliang.com/pid-filter-tuning-blackbox/ | 2026-08-01 | Secondary practical guide; values are contextual heuristics |
| BF40 | Betaflight 4.0 Tuning Notes | Betaflight | historical 4.0 documentation | https://betaflight.com/docs/wiki/tuning/4-0-Tuning-Notes | 2026-08-01 | Source for prop-size/max-motor-frequency examples and delay tradeoff |
| BF-PID | PID Tuning Guide | Betaflight | current docs | https://betaflight.com/docs/wiki/guides/current/PID-Tuning-Guide | 2026-08-01 | D-term/noise and tuning-risk context |
| BF-FS | Freestyle Tuning Principles | Betaflight | current docs | https://betaflight.com/docs/wiki/guides/current/Freestyle-Tuning-Principles | 2026-08-01 | Filter/phase-delay guidance |
| BF-RPM | DShot RPM Filtering | Betaflight | current docs | https://betaflight.com/docs/wiki/guides/current/DSHOT-RPM-Filtering | 2026-08-01 | eRPM, motor poles, and harmonic RPM filtering |
| BF-CLI | Command Line Interface | Betaflight | current docs | https://betaflight.com/docs/wiki/guides/current/Cli | 2026-08-01 | Filter/motor settings vocabulary |
| BF-SRC | RPM filter and DShot source | Betaflight | tag `2026.6.1`, commit `6dbc4218fd6bc33bf16ea32c670304d4f89321d5` | `betaflight/src/main/flight/rpm_filter.c`; `betaflight/src/main/drivers/dshot.c`; related headers | 2026-08-05 | Primary local implementation evidence |
| PTB | PIDtoolbox spectrum/delay implementation | PIDtoolbox | commit `1e12abb23188183f0f21998a6a89af3719ded22a` | `PIDtoolbox/PTspecUIcontrol.m` and related spectrum code | 2026-08-01 | Free source; Pro implementation unavailable |
| BLV | Blackbox Explorer spectrum implementation | Betaflight Blackbox Explorer | commit `1222587e162fd2c881ee2ea3d74ec91c2397891d` | `blackbox-log-viewer/src/graph_spectrum_calc.js`; related plot/UI files | 2026-08-05 | Reference behavior, not copied architecture; functional source unchanged from prior pin |
| AF-SRC | Airframe native spectrum implementation | Airframe | working tree observed 2026-08-01 | `Airframe/Packages/BlackboxAnalysis/Sources/BlackboxAnalysis/Spectrum/`; `Airframe/Packages/AirframeUI/Sources/AirframeUI/Spectrum/` | 2026-08-01 | Primary evidence for current Airframe behavior |
| BF31 | Gyro and Dterm Filtering Recommendations 3.1 | Betaflight | archived 3.1 guidance | https://betaflight.com/docs/wiki/guides/archive/Gyro-And-Dterm-Filtering-Recommendations-3-1 | 2026-08-02 | Explicitly says resonance points cannot be predicted and vary per frame and prop |
| UAVT | Tuning hub and PID Tuning Principles | UAV Tech | site and linked guide accessed 2026-08-02 | https://theuavtech.com/tuning/ and https://theuavtech.com/wp-content/uploads/2020/10/UAV-Tech-PID-Tuning-Principles.pdf | 2026-08-02 | Canonical expert hub; distinguishes general principles and craft-specific practice, and lists antennas, cracked frames, and other peaks as Dynamic Notch targets |
