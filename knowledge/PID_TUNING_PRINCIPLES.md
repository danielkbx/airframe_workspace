# PID Tuning Principles

- Status: research reference; historical firmware-specific guidance is non-normative
- Last reviewed: 2026-08-05
- Scope: PID-F signal flow, response interpretation, gain relationships, practical tuning limits, and cautious application to Airframe analysis
- Normative decisions: `../.agents/MEMORY.md`
- Related research: [Spectrum Tuning Guides](SPECTRUM_TUNING_GUIDES.md) and [Upstream Analysis Tools](UPSTREAM_ANALYSIS_TOOLS.md)
- Related implementation: `Airframe/Packages/BlackboxAnalysis/Sources/BlackboxAnalysis/StepResponse/` and `Airframe/Packages/BlackboxAnalysis/Sources/BlackboxAnalysis/Chirp/`

## Executive Essence

A rate controller compares the commanded angular rate (setpoint) with measured motion (gyro), then uses feedback and command-derived terms to drive the motor mixer. Tuning seeks fast, accurate tracking without sustained overshoot or oscillation, while preserving noise, thermal, actuator, and mechanical margins. Filtering and PID tuning are coupled because high-frequency gyro noise constrains usable D gain and every filter changes phase response.

UAV Tech and Chris Rosser both organize tuning around observable response rather than isolated gain numbers. Their durable value is the distinction between damping balance, overall gain, sustained-error correction, and Feedforward tracking. Their concrete commands, sliders, thresholds, and example values belong to their firmware and craft context and are not current Airframe recommendations.

## Evidence Matrix

| ID | Claim | Source | Grade | Scope | Airframe impact | Status |
|---|---|---|---|---|---|---|
| PTP-001 | Betaflight's rate controller compares setpoint with gyro feedback to form PID error; P responds to current error, I accumulates error, D responds to gyro change, and Feedforward responds to setpoint change before feedback error develops. | CR45-PID, BF-SRC | A/C | Betaflight PID-F controller | Use these signals as distinct measured inputs/outputs; never describe Feedforward as another feedback-error gain. | verified |
| PTP-002 | A practical tuning objective is fast setpoint tracking without sustained overshoot or oscillation; critically damped response is a useful conceptual target, not a binary state established by one noisy flight. | UAVT, CR45-PID | C | General tuning interpretation | Explain peak, settling, and tracking together; do not label a log definitively “critically damped.” | partially verified |
| PTP-003 | P:D balance primarily changes damping behavior, while common P/D scaling increases control authority without intentionally changing that balance. Modern nonlinear features and saturation mean the ratio is not a complete plant model. | UAVT, CR45-PID | C | Roll/pitch tuning guidance | Separate damping balance from common gain in analysis and future recommendations. | partially verified |
| PTP-004 | P:I balance concerns the speed and stability of sustained-error correction. The claim that I gain only changes wind-up speed assumes no limiting, leak, relax, anti-windup, saturation, or other nonlinear behavior and is not generally sufficient for current Betaflight. | CR45-PID, BF-SRC | A/C | Betaflight 4.5 explanation versus current firmware | Treat persistent tracking error and slow oscillation as evidence, not as a one-variable diagnosis. | partially verified |
| PTP-005 | Filtering should be established before gain tuning because residual noise, especially after D amplification, constrains usable D gain and can cause vibration or motor heating. | UAVT, CR45-FILTER, BF-FS | B/C | Practical tuning sequence | Link PID interpretation to the measured gyro/D-term spectrum and filter-delay context. | verified |
| PTP-006 | Step response can summarize rise, normalized peak, overshoot, settling, latency, and final tracking, but estimator method, excitation, accepted windows, and noise affect the curve. | UAVT, CR45-PID, AF-STEP | A/C | Blackbox-derived response analysis | Airframe must expose measurement quality and method rather than treating a reference curve as ground truth. | verified |
| PTP-007 | In setpoint/gyro traces, persistent initial lag is consistent with too little Feedforward, leading response or end-of-move overshoot is consistent with too much, and close tracking without sustained overshoot is the intended qualitative result. Other causes must be excluded. | CR45-PID | C | Betaflight 4.5 Blackbox examples | Use these as review cues, never as an automatic single-cause classifier. | heuristic |
| PTP-008 | Dynamic Damping varies active D with move conditions. The BF 4.5 workflow uses `D_MIN` debug data to inspect actual roll/pitch D and aims for little boost in normal flight with maximum boost reserved for aggressive moves. | CR45-PID | C | Betaflight 4.5 only | Version-gate debug interpretation and do not project this workflow onto other firmware generations without source verification. | verified |
| PTP-009 | Raising common controller gain can improve tracking and propwash response until noise, oscillation, motor heat, actuator saturation, or mechanical authority becomes limiting. Maximum tolerable gain is not automatically the optimal tune. | UAVT, CR45-PID | C | Practical tuning limits | Report limiting evidence separately; never score higher absolute gain as inherently better. | partially verified |
| PTP-010 | Yaw has different authority and plant dynamics from roll/pitch, so the common absence of yaw D and the useful gain balance can differ. Concrete yaw gain advice is craft- and version-specific. | UAVT, CR45-PID | C | Multirotor yaw tuning | Keep per-axis evidence and avoid copying roll/pitch thresholds to yaw. | partially verified |
| PTP-011 | Concrete I-Term Relax, Anti Gravity, Dynamic Idle, TPA, Feedforward, motor-output, and slider recommendations in the Rosser deck describe a BF 4.5 workflow and are not current defaults. | CR45-PID | C | Betaflight 4.5 | Preserve them as historical interpretation context only. | verified |
| PTP-012 | Airframe's Tune Score deliberately separates evidence confidence from tune quality and uses damping, robustness, stability margin, and tracking fidelity instead of rewarding absolute bandwidth or gains. | AF-FR | A | Current Airframe implementation | Expert guides may explain components but must not supply unvalidated score thresholds. | verified |

## Terminology And Measurement Mapping

| Tuning term | Measured or modeled quantity | Airframe interpretation |
|---|---|---|
| Setpoint / command | Desired angular rate from the controller input | Reference signal; not actual aircraft motion |
| Gyro feedback | Measured angular rate | Closed-loop output used for tracking comparison |
| PID error | Setpoint minus gyro in the simplified rate-loop view | Input to P and I behavior; exact firmware processing remains versioned |
| P term | Response proportional to current error | Tracking authority that can contribute to overshoot when balance or gain is excessive |
| I term | Accumulated, processed error | Sustained-error correction affected by relax, anti-windup, saturation, and other firmware behavior |
| D term | Damping derived from gyro change in current Betaflight | High-frequency-sensitive feedback term; distinguish configured gain from active Dynamic Damping |
| Feedforward | Command-change-derived contribution | Anticipatory tracking term, evaluated against setpoint/gyro timing and overshoot |
| Rise / response time | Time for response to reach a defined level | Definition depends on the calculator; compare only compatible methods |
| Normalized peak | Maximum response relative to the final or reference level | Evidence for resonance or overshoot, not a complete damping classification |
| Settling | Time and behavior around the final level | Requires a defined tolerance and sufficient observation window |
| Bounceback | End-of-move reversal or oscillatory correction | Symptom that may arise from P:D balance, Feedforward, I behavior, filtering, saturation, or mechanics |
| P:D balance | Relative proportional and derivative influence | Damping relationship, distinct from common gain scaling |
| P:I balance | Relative proportional and integral influence | Sustained tracking/stability relationship, not a universal fixed ratio |

## UAV Tech Source Interpretation

UAV Tech presents tuning as a staged control-loop process: establish filtering, find P/D balance from sharp response, increase common P/D gain while retaining the selected balance, and then adjust Feedforward, yaw, and I behavior. The guide's strongest durable contribution is its response vocabulary: overshoot and fast bounceback are associated with underdamped behavior, while a response that stops short and then approaches the target is associated with excessive damping. Slow bounceback is presented as an I-term/windup clue.

These are diagnostic hypotheses, not exclusive causal rules. The guide dates from the Betaflight 4.1 era. Its CLI paste, gain ranges, slider extent comments, D_min behavior, yaw multipliers, and example values must not be applied to current Betaflight without independent version verification.

## Chris Rosser BF 4.5 Source Interpretation

Chris Rosser's two-part masterclass is an expert secondary source grounded in Blackbox plots, PIDtoolbox step responses, practical tuning flights, and explicit BF 4.5 controls. It distinguishes:

- a common Master Multiplier from P:D and P:I balance;
- fast P/D-related oscillation from slower I-related movement;
- feedback correction from Feedforward tracking;
- static configured D from move-dependent Dynamic Damping;
- useful signal retention from noise transmission and filter delay.

The PID deck includes real visual examples of too little, too much, and approximately correct Feedforward, plus a PIDtoolbox step-response example. These examples support qualitative review. They do not establish universal numeric thresholds, sample sizes, or automatic classifications.

## Historical And Version Caveats

- Both Rosser decks target Betaflight 4.5 and Configurator UI available in March 2024.
- UAV Tech's linked guide reflects Betaflight 4.1-era terminology and behavior.
- CLI commands and UI slider names may be removed, renamed, rescaled, or semantically changed in later firmware.
- `D_MIN` debug interpretation, Dynamic Damping, I-Term Relax, Anti Gravity, Absolute Control, TPA, Feedforward Boost, and related controls require firmware-versioned source verification.
- Prop-size tables, Master Multiplier ranges, dynamic-idle values, and gain examples are craft-specific expert recommendations, not general control laws.
- “Smaller or larger quads need more D/less P” is a practical generalization, not a universal geometry rule.
- “The maximum tolerable Master Multiplier gives the best tune” ignores robustness margin, damaged-prop tolerance, efficiency, thermal headroom, use case, and uncertainty.

## Airframe Relevance

- **Spectrum:** filtering/noise evidence remains in [Spectrum Tuning Guides](SPECTRUM_TUNING_GUIDES.md); PID interpretation should consume measured gyro, D-term, motor-harmonic, and filter-delay facts instead of duplicating them.
- **Step Response:** Airframe's Wiener-deconvolution result provides normalized peak and response time from arbitrary usable excitation. It is methodologically related to, but not identical with, the PIDtoolbox curves shown by Rosser.
- **Frequency Response Tune Score:** the Damping component already combines closed-loop resonance with derived-step overshoot and settling. Expert guides explain why those metrics matter but do not calibrate score thresholds.
- **Future CHIRP assistance:** recommendations must remain reviewable, version-aware, bounded by coherence and robustness evidence, and separate from filter changes. No guide authorizes blind PID application.
- **Recorded settings:** any displayed PID values must continue to come from the selected segment's Blackbox header. Guide defaults and imported configurations must never fill missing fields.

## Source Register

| Source ID | Title | Author/project | Version/date | URL or local path | Accessed | Notes |
|---|---|---|---|---|---|---|
| UAVT | UAV Tech PID Tuning Principles | UAV Tech | October 2020; Betaflight 4.1-era guide | https://theuavtech.com/wp-content/uploads/2020/10/UAV-Tech-PID-Tuning-Principles.pdf | 2026-08-05 | Expert secondary guide; general principles separated from historical commands and numeric advice |
| CR45-FILTER | BF 4.5 Tuning Guide Part 1: Filters | Chris Rosser | created 2024-03-20 | `sources/chris-rosser/BF-4.5-Filter-Tuning.pdf`; https://www.youtube.com/watch?v=E3s5XYk3M74 | 2026-08-05 | Private archived Patreon deck plus public companion video; SHA-256 recorded in source README |
| CR45-PID | BF 4.5 Tuning Guide Part 2: PIDs | Chris Rosser | created 2024-03-29 | `sources/chris-rosser/BF-4.5-PID-Tuning.pdf`; https://www.youtube.com/watch?v=1oYoVE4xu1U | 2026-08-05 | Private archived masterclass deck plus public companion video; SHA-256 recorded in source README |
| BF-FS | Freestyle Tuning Principles | Betaflight | current docs | https://betaflight.com/docs/wiki/guides/current/Freestyle-Tuning-Principles | 2026-08-05 | Official filter-delay and D-term/noise context |
| BF-SRC | PID controller source | Betaflight | tag `2026.6.1`, commit `6dbc4218fd6bc33bf16ea32c670304d4f89321d5` | `upstreams/betaflight/src/main/flight/pid.c`; related headers | 2026-08-05 | Primary current implementation evidence; use for version checks rather than importing old settings |
| AF-STEP | Native Step Response implementation | Airframe | working tree observed 2026-08-05 | `Airframe/Packages/BlackboxAnalysis/Sources/BlackboxAnalysis/StepResponse/` | 2026-08-05 | Primary evidence for current Airframe response semantics |
| AF-FR | Frequency Response and Tune Score implementation | Airframe | working tree observed 2026-08-05 | `Airframe/Packages/BlackboxAnalysis/Sources/BlackboxAnalysis/Chirp/` | 2026-08-05 | Primary evidence for current score components, confidence separation, and limitations |
