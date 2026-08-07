# Current Plan

## Spectrum Interaction And Document-State Coalescing (Implemented; Live Acceptance Pending 2026-08-07)

### Think Before Coding

- Separate Spectrum interaction cadence from document-state publication and keep domain mutations independent from UI-state save cadence.

### Simplicity First

- Spectrum commits only at interaction boundaries; the workspace retains one latest `Metadata.State` candidate behind a one-second trailing debounce.

### Surgical Changes

- Preserve FFT, render models, document format, and the 350 ms domain-save path. Equality-gate only the existing Spectrum geometry publications and route main/reference UI state through one staging API.

### Goal-Driven Execution

- Workspace/controller and platform persistence tests, all AirframeUI package tests, and macOS/iPadOS builds pass. Physical large-log panning/resize profiling remains tracked in `TASKS.md`.

## Step Response Horizontal Zoom (Implemented; Live Acceptance Pending 2026-08-07)

### Think Before Coding

- Keep Step Response analysis/cache identity independent of its horizontal viewport. Treat semantic results, geometry projection, interaction state, and persistence as separate cadences.
- Keep the transient vertical crosshair in its own interaction-cadence overlay, with only an X/time chip and no Y readout, so pointer motion never invalidates the semantic trace Canvas.

### Simplicity First

- Use one 1x...10x time window shared by all classic Step Response panes and traces. Preserve the Y domain and leave Frequency Response/Spectrogram unchanged.

### Surgical Changes

- Persist only normalized viewport fractions in existing document/preset Step Response storage. Draw visible uniform samples plus one neighbor without adding an analysis or cache layer.

### Goal-Driven Execution

- Package policy tests, focused app persistence/preset tests, and both platform builds pass. Remaining physical interaction and profiling gates are tracked in `TASKS.md`.

## X-Range Measurement (Implemented 2026-08-07; Live Validation Pending)

### Think Before Coding

- Keep mixed X domains pane-bound and use exact display-scaled samples, reliable-only Frequency Response data, neighboring boundary samples, and recorded gaps.

### Simplicity First

- One committed environment state, one leaf-local coalesced drag draft, one native tracking layer, one bounded overlay, and one streaming statistics/extrema reducer serve every supported surface without persistence or a new cache.

### Surgical Changes

- Spectrum snap paths were removed while its pixel-bounded peak index remains. Existing chart render models stay intact; measurement tasks belong to their surfaces and reject stale publications.
- Pane-bound inspector results reuse each trace's render color, omit redundant pane names, consolidate related values into compact rows, and expose localized native help for every metric label. Oscillation output appears only for a stable estimate; rejection copy and completed-period counts remain hidden.
- Drag updates remain inside the overlay leaf, are deduplicated and capped at 120 visible updates per second, reuse precomputed domains and a retained formatter, and redraw only bounded rectangles. Calculation handles are non-observable so task replacement cannot invalidate complete chart surfaces.

### Goal-Driven Execution

- Package tests, state tests, and both platform builds pass. Complete the remaining physical gesture, large-log performance, and repeated open/measure/close lifecycle checks before declaring live acceptance complete.

## Tuning Interpretation, Filter Score, and Assistance Roadmap (Approved 2026-08-05)

### Summary

Build Airframe's tuning support in four maturity levels:

1. Explain existing measurements and improve capture feedback.
2. Add validated assessments, including a strict Filter Score.
3. Provide active but non-mutating next-step guidance.
4. Extend the existing CHIRP PID Tuning Assistant.

The roadmap separates measurement from interpretation, tune quality from evidence confidence, filter assessment from PID assessment, observations from causal diagnosis, and guidance from automatic configuration changes. Each numbered measure is independently implementable. Later measures depend on the stated earlier evidence contracts.

| Order | Measure | Maturity | Dependency |
|---:|---|---|---|
| 1 | [Contextual tuning guides](#measure-1-contextual-tuning-guides) | Views and help | None |
| 2 | [Step Response evidence and capture diagnostics](#measure-2-step-response-evidence-and-capture-diagnostics) | Views and help | None |
| 3 | [Step Response measurement expansion](#measure-3-step-response-measurement-expansion) | Neutral measurements | 2 |
| 4 | [Tune Score Key Findings](#measure-4-tune-score-key-findings) | Interpretation of existing score | Existing Tune Score |
| 5 | [Spectrum Filter Review](#measure-5-spectrum-filter-review) | Neutral measurements and visualization | Existing Spectrum |
| 6 | [Filter Score calibration and release](#measure-6-filter-score-calibration-and-release) | Strong assessment | 5 plus validation fixtures |
| 7 | [Cross-flight Tuning Review](#measure-7-cross-flight-tuning-review) | Comparative assessment | 3, 4, optionally 6 |
| 8 | [Guided next-flight actions](#measure-8-guided-next-flight-actions) | Active help, no setting changes | 4-7 |
| 9 | [Blackbox Test Setup Assistant](#measure-9-blackbox-test-setup-assistant) | Active preparation | 2, 5, FC communication |
| 10 | [CHIRP PID Tuning Assistant extension](#measure-10-extend-the-existing-chirp-pid-tuning-assistant) | PID recommendations and explicit application | 6, 8, 9 plus existing CHIRP algorithm gates |
| 11 | [Separate Filter Tuning Assistant](#measure-11-future-separate-filter-tuning-assistant) | Future active filter help | Stable Filter Score history |

### Think Before Coding

- UAV Tech and Chris Rosser provide expert interpretation, not universal thresholds. Betaflight 4.5 settings and examples never become current Airframe defaults.
- A single symptom must not map directly to one PID term. Overshoot, latency, noise, saturation, Feedforward, filtering, mechanics, and estimator quality can interact.
- Filter Score means the observed filter outcome in one flight and selected range, not a globally optimal filter configuration.
- Tune Score and Filter Score keep score and Confidence independent. Missing evidence produces `No Score`, not a lower score.
- Filter Score uses strict evidence gating: usable unfiltered and filtered gyro for Roll and Pitch, filtered D-term, motor outputs, throttle, eRPM, a valid motor-pole count, adequate duration/sample rate/throttle-RPM coverage, and repeatable measurements. D-term prefilter data strengthens evidence but is not mandatory because it is debug-mode dependent.
- No fixed `90 Hz` boundary, prop-size table, Master Multiplier limit, or Rosser example value becomes a scoring constant.
- Motor temperature, damaged-prop tolerance, mechanical integrity, and thermal headroom cannot be proven from Blackbox data and remain explicit limitations.
- Tune findings stay inside Spectrum, Step Response, Frequency Response, and the future Tuning Review. They do not become Overview log-integrity checks.
- The existing CHIRP assistant remains PID-only. It may consume Filter Score as a prerequisite and safety signal, but it never changes filters.

### Simplicity First

#### Measure 1: Contextual Tuning Guides

Add compact localized help beside existing analysis controls.

- Spectrum explains the signal path from unfiltered gyro through gyro filters and PID/D-term to motor output, RPM Filter versus Dynamic Notch responsibilities, the delay/noise tradeoff, and why measured harmonics matter more than prop-size tables.
- Step Response explains setpoint, gyro response, normalized target, peak, latency, overshoot, settling, final error, usable input, and why one curve cannot uniquely diagnose P, D, I, or Feedforward.
- Frequency Response explains Tune Score components, Confidence, CHIRP coverage, limitations, and the relationship between frequency-domain response and derived step response.
- Use native info popovers and short inspector guidance. Summarize Knowledge Base claims; do not embed copyrighted slide images or long quotations.

Acceptance: every claim maps to Knowledge Base evidence; BF 4.5 examples are visibly historical; localization, accessibility, previews, and macOS/iOS layouts pass.

#### Measure 2: Step Response Evidence and Capture Diagnostics

Replace generic failure strings with structured evidence:

- Total candidate windows.
- Windows below minimum input.
- Windows rejected by quality checks.
- Windows excluded by the selected rate class.
- Accepted windows.
- Missing setpoint, gyro, sample-rate, or range evidence.
- Selected ranges that are too short or contain no suitable moves.

Give evidence-capture help: request several clean and decisive moves on the missing axis, avoid continuous stick activity that prevents response isolation, expand or move the selected range, select the matching rate class, and identify missing firmware/logging fields without inventing replacements. Keep evidence-capture advice separate from tune-change advice.

Acceptance: structured counts exactly match calculator decisions, every unavailable result has a typed reason, and no capture message recommends a PID or filter change.

#### Measure 3: Step Response Measurement Expansion

Extend every successful axis result with:

- Existing latency: time to 50% response.
- Rise time: 10% to 90% of the normalized target.
- Peak value.
- Overshoot: `max(peak - 1, 0) * 100`.
- Settling time: the first point after which the remaining response stays within `1.0 +/- 5%`.
- Final tracking error: absolute mean error over the final 10% of samples.
- Accepted/candidate window ratio.
- Response duration and estimator method/version.

Retain the normalized `1.0` reference line. Add metrics to the existing per-log/axis presentation, show evidence counts, explain unavailable rise/settling values, and add no qualitative good/bad labels yet. Reuse CHIRP-derived step metric definitions where equivalent.

Acceptance: synthetic curves cover every metric and unavailable case; existing PIDtoolbox comparison behavior stays within current tolerance; old persistent-cache entries miss safely after the Step Response dataset version bump.

#### Measure 4: Tune Score Key Findings

Add a non-collapsible `Key Findings` block below the Tune Score summary and above component rows. Generate no more than three deterministic findings: weakest component, limiting axis, concrete supporting measurements, material Confidence/coverage limitation, and any applied hard-cap reason.

Do not change Tune Score v1 mathematics, infer a PID adjustment, repeat all component rows, combine Confidence into the score, or call a tune optimal.

Acceptance: ordering is deterministic, every finding resolves to displayed evidence, and Confidence never changes the score or finding severity.

#### Measure 5: Spectrum Filter Review

Add a descriptive `Filter Review` above the existing filter configuration. It follows the selected log and In/Out range but computes independently of the currently visible Spectrum traces.

1. Gyro input noise: unfiltered gyro spectrum, measured motor fundamental/harmonic ridges, and broadband noise outside those ridges.
2. Filtered gyro result: residual harmonic energy, broadband attenuation, and frequencies where substantial energy remains.
3. Controller output: D-term high-frequency energy, motor-output oscillatory energy, and per-axis/weakest-motor evidence.
4. Cost and configuration: gyro/D-term/total delay, RPM harmonic count and weights, Dynamic Notch configuration, missing evidence, and version limitations.

Add a compact signal-flow summary. Evidence rows may highlight their measured plot regions. Motor bands follow measured eRPM ridges. Useful-control/noise separation derives from setpoint energy and observed motor-frequency coverage, not a static `90 Hz` boundary. Show harmonic occupancy and ridge-to-background strength before discussing RPM weight efficiency. Rosser AOS/Easy values remain labeled historical BF 4.5 examples.

This measure produces no numeric score and no setting recommendation.

Acceptance: harmonic regions follow RPM in synthetic and real fixtures, missing signals produce precise limitations, and changing the displayed Spectrum field cannot change Filter Review results.

#### Measure 6: Filter Score Calibration and Release

Introduce a versioned Filter Score with the same presentation language as Tune Score: `1.0` to `10.0`, `Excellent` through `Critical`, independent High/Medium/Low Confidence, ordered `No Score` reasons, per-component facts/formulas, and a visible algorithm version.

Components:

1. `Gyro Attenuation`: post-/pre-filter spectral-energy ratios across measured harmonic bands and the derived broadband-noise region, aggregated conservatively across Roll/Pitch.
2. `D-Term Cleanliness`: normalized high-frequency D-term energy plus pre-/post-filter ratio when matching debug data exists. Recorded D gains must prevent naive absolute-amplitude comparisons across tunes.
3. `Motor Output Cleanliness`: oscillatory motor-command energy normalized against usable motor-command variation, weakest-motor evidence, motor imbalance, and separate saturation/clipping limits.
4. `Delay Efficiency`: gyro and D-term delay evaluated jointly with achieved attenuation; neither minimum delay nor maximum attenuation wins in isolation.

Use the Tune Score convention of a conservative weakest-channel plus channel-mean component result and a weighted geometric overall mean. Define safety caps only from validated evidence. Confidence never changes the numeric score. A missing required component returns `No Score`; remaining components are not silently reweighted.

Calibration gates before numerical thresholds ship:

- Synthetic signals with known filter transfer functions.
- Amplitude-scaling invariance.
- Sample-rate and FFT-resolution invariance within documented tolerance.
- Motor-ridge movement with RPM and known missing/extra harmonics.
- Clean, noisy, over-filtered, resonant, and motor-output-oscillation fixtures.
- Multiple craft sizes and operating ranges.
- Repeatability across valid windows from the same flight.
- Expert labels recorded independently of the calculated score.
- False-positive review for smooth low-excitation flights.

Record every threshold, weight, and hard cap with fixture evidence. Unsupported values remain unavailable rather than being copied from BF 4.5 guidance.

Place Filter Score at the top of the Spectrum inspector above Filter Review. Reuse the Tune Score gauge, rating, Confidence, component rows, and explanation pattern. Show `No Score` with capture instructions and state that the result was observed in the selected flight/range. Do not create a combined Tune+Filter score.

Acceptance: strict gates suppress incomplete evidence; score is invariant under supported amplitude scaling; Confidence cannot alter an otherwise identical score; aggregation/caps are deterministic; thresholds pass documented calibration review; controlled filter changes produce explainable component changes.

#### Measure 7: Cross-Flight Tuning Review

Use existing attached reference logs first. Add a comparison summary without a new document workflow.

- Show Tune Score, Filter Score, their algorithm versions, Step Response metrics/evidence, recorded PID/D Max/Feedforward/filter configuration, descriptive P:D and P:I ratios, firmware, and analysis range.
- Let the user select one reference as baseline and show values plus deltas.
- Warn instead of silently comparing different algorithm versions, firmware, filters, rate profiles, motor-pole settings, or logging methods.
- Keep Roll, Pitch, and Yaw separate. Never infer that the newest or highest-gain tune is best. Do not apply Roll/Pitch D reasoning to Yaw.
- Do not introduce an aggregate overall tuning score.

Acceptance: baseline selection and ordering are deterministic, every delta resolves to the correct segment, and incompatible comparisons remain visibly qualified.

#### Measure 8: Guided Next-Flight Actions

Add deterministic, non-mutating action cards: improve the recording, inspect an axis/signal, repeat a test, check mechanics, validate filters before PID work, collect CHIRP evidence, or stop because of saturation/severe oscillation/unreliable evidence.

Every action states its triggering evidence, why it matters, the exact next observation or flight procedure, its completion condition, and that Airframe changed no setting. Do not output numeric PID/filter values. Feedforward signatures may be described only as consistent with a condition, never as a single-cause diagnosis.

Acceptance: every action has a concrete evidence trigger; insufficient or severe evidence suppresses recommendations; no unsupported setting value can be generated.

#### Measure 9: Blackbox Test Setup Assistant

Implement the existing setup-assistant concept before PID recommendations:

- Select Filter Review, Step Response, or CHIRP.
- Read firmware generation and current FC configuration.
- Verify fields, debug mode, logging rate, eRPM, motor poles, and Blackbox device.
- Detect legacy CHIRP phase-only payloads.
- Generate version-scoped setup changes and preview every change.
- Apply only after explicit confirmation or emit a CLI diff.
- Provide test-flight and abort/safety instructions.
- Restore temporary debug/logging settings when requested.

This assistant prepares evidence. It does not tune PIDs or filters.

Acceptance: setup changes are previewed/reversible, unsupported firmware/debug layouts are blocked, and cancellation leaves no hidden FC change.

#### Measure 10: Extend the Existing CHIRP PID Tuning Assistant

Preserve the existing Welch estimation, coherence filtering, controller reconstruction, plant identification, loop-shaping synthesis, per-iteration clamps, reviewable PID/slider proposal, MSP/CLI application paths, and two-flight convergence requirement.

The measurement basis is the closed-loop response `T(f) = setpoint -> gyro`. Unlike the Configurator's craft-agnostic fixed-target scaling, Airframe reconstructs the recorded controller and identifies a craft-specific plant before proposing gains:

1. Estimate `T(f)` with Hann-windowed Welch cross spectra, 50% overlap, magnitude-squared coherence, and rejection of bins below the validated coherence gate. Derive bandwidth, resonance, phase margin, sensitivity, and frequency-domain step response.
2. Reconstruct the recorded controller `C(f)` analytically from header PID/D Max/Feedforward values, D-term filters, and loop rate.
3. Recover loop response `L = T / (1 - T)` and plant `G = L / C` over reliable bins. Fit a coherence-weighted second-order-plus-dead-time model and publish fit quality as first-class evidence.
4. Derive achievable bandwidth and phase-margin targets from identified delay, optionally biased by explicitly selected Racing/Freestyle/Cinematic intent. Synthesize P/I/D/Feedforward through loop shaping and map the result to simplified-tuning sliders only when slider granularity can represent it safely.
5. Clamp every iteration, back off for resonance, never loosen filtering, and refuse a proposal when coherence, fit quality, saturation, or required evidence fails.

Internal delivery order:

1. Pure-Swift offline algorithm spike in `BlackboxAnalysis`, exposed through an `AirframeCLI` command that prints measurements, fit quality, limitations, and proposed sliders for a CHIRP `.bbl`.
2. Synthetic known-plant round trips plus side-by-side comparison with Configurator output on the same representative real CHIRP logs. Existing ordinary Step Response fixtures do not satisfy this gate.
3. Version-scoped MSP read/write for CHIRP and simplified-tuning parameters plus reversible CLI-diff generation.
4. Assistant UI and document-owned tuning-session state machine.
5. Convergence tracking, optional use-case targets, localization, and any separately validated Yaw strategy.

Before the offline spike, verify the exact Betaflight 2026.6 CHIRP/debug field layout against pinned firmware source and decide from evidence whether slider granularity is sufficient or per-term output is required. Yaw remains measurement-only until that separate decision is validated.

Add:

1. A passing, adequately confident Filter Score as prerequisite. It may come from a separate filter-validation flight but must match craft identity, firmware generation, motor poles, and a fingerprint of relevant filter configuration. Any later filter change invalidates it.
2. The structured capture diagnostics from Measures 2 and 9. Failed CHIRP completeness, coherence, saturation, stick isolation, or axis coverage produces guidance but no PID recommendation.
3. Tune Score Key Findings plus current/proposed controller values, modeled response, phase margin, sensitivity, expected step response, and limitations.
4. A relative noise regression guard after each gain change. Compare filtered gyro, D-term, and motor output against the session baseline; stop and recommend rollback beyond validated limits. This is not a replacement Filter Score.
5. Versioned user-owned tuning-session history in the Airframe document: settings fingerprints, accepted proposals, applied values, score versions, evidence references, and convergence. Recomputable spectra/render data stay in the derived cache. Raw logs remain session-only until placed in a document.
6. Roll/Pitch-first safety. Yaw stays measurement-only until separately validated. Never change filters or apply FC changes without explicit confirmation. Produce a reversible CLI diff and retain previous values. A filter change terminates the PID convergence sequence and requires a new baseline.

Acceptance: fingerprint mismatch blocks recommendations, MSP writes require confirmation, CLI diffs reproduce proposals, noise regression stops an iteration, convergence requires two matching flights, and document close cancels all work and releases session owners.

#### Measure 11: Future Separate Filter Tuning Assistant

Keep active filter tuning outside the CHIRP PID assistant. It becomes eligible only after Filter Score v1 is stable across representative craft, controlled configurations have been compared on the same craft, current Betaflight filter semantics are source-verified, and delay/noise/motor-output/temperature/damaged-prop validation procedures exist.

If separately approved, it changes one filter dimension per iteration, requires a new validation flight, compares against the exact previous configuration, never changes filters and PIDs in one iteration, invalidates the PID plant model after filter changes, and requires explicit review plus reversible application.

### Surgical Changes

- Implement each measure as a separate public Airframe commit after the mandatory user decision about changelog relevance. Do not bundle the roadmap into one feature branch or infer approval for a later measure from approval of an earlier one.
- Expected public `BlackboxAnalysis` interfaces are `AnalysisStepResponse.Evidence`, `AnalysisStepResponse.UnavailableReason`, extended `AnalysisStepResponse.AxisResult` metrics, `AnalysisFilterReview`, versioned `AnalysisFilterScore`, and a small deterministic `AnalysisTuningFinding` shared by score presentations.
- Later assistant phases add versioned tuning-session state, a filter-configuration fingerprint, proposed/applied configuration deltas, and evidence/convergence records.
- Calculations and thresholds belong in `BlackboxAnalysis`; header/configuration extraction in `BlackboxReader`; localized text in `AirframeCaptions`; presentation in existing Spectrum, Step Response, and Frequency Response features; FC setup/application in `MSP` and `FlightController`.
- Domain interfaces remain pure, `Sendable`, independent of SwiftUI/localization, deterministic for identical input, explicitly versioned when scored/persisted, and able to represent missing evidence without strings.
- No external dependency or upstream-reference modification is allowed.
- Bump the Step Response persistent dataset version when `AxisResult` changes. Give Filter Review its own versioned semantic cache. Cache measurements/bands/evidence, not pixels, localized text, findings, or SwiftUI state. Keys include algorithm version, log identity, selected range, signal identities, sample-rate policy, and relevant configuration fingerprint.
- All app-side work uses `ProcessingActivityCounter`. New document-scoped tasks/caches require explicit ownership, idempotent shutdown, cancellation, late-publication rejection, RAM clearing, and memory-pressure behavior.
- Measures 1-8 need no external API or Airframe document-format change. Measure 10 adds a versioned user-owned tuning-session schema; migration preserves previous settings and evidence provenance.

### Goal-Driven Execution

For every selected measure:

1. Re-read the relevant Knowledge Base claims and current Betaflight source before defining semantics or thresholds.
2. Implement only that measure and its declared prerequisite interface changes.
3. Add focused synthetic, fixture, missing-evidence, determinism, and boundary tests described above.
4. Run relevant full package suites, app-hosted tests, macOS and generic iOS Simulator builds, String Catalog validation, and `git diff --check`.
5. Verify every new SwiftUI file has a realistic production-model preview and every user-facing string is localized.
6. For new data-backed work, perform document lifecycle tests and a live repeated open/use/close pass; require idle CPU, no late analysis/cache writes, zero pending writes, released document/window/workspace/cache roots, and bounded physical footprint.
7. Use representative logs for live acceptance. Do not promote calibration-derived labels or recommendations until their specific evidence gates pass.
8. Before a public commit, obtain the user's changelog-relevance decision and follow the mandatory trailer rule. Do not commit or push merely because a measure passed verification.

Roadmap success means Airframe can progress from transparent evidence, through calibrated and explainable assessments, to reversible active assistance without presenting historical expert examples as universal rules or allowing weak evidence to produce strong tuning actions.

### Assumptions and Defaults

- Documentation, code, captions, and planning artifacts remain English.
- Filter Score uses the selected strict evidence gate and requires Roll/Pitch; Yaw remains descriptive until separately validated.
- Filter Review is broadly available while numerical Filter Score is intentionally less available.
- Tune Score v1 remains unchanged during Measures 1-5.
- No combined Tune+Filter score is introduced.
- The existing CHIRP PID Assistant algorithm is extended, not replaced, and never changes filters.
- Active Filter Tuning assistance is a separate future project and is not approved by this roadmap alone.
- This roadmap records future implementation scope. Selection and implementation of each measure remain separate user decisions.
