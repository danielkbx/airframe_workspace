# Battery Sag Score Plan

- Status: approved future work
- Release scope: explicitly excluded from Airframe 1.0
- Earliest implementation: after the Airframe 1.0 feature freeze is lifted

## Summary

Add one `Sag Score` row to the existing Power card. The score describes observed temporary voltage collapse during strong current excursions. It must never be presented as internal resistance, remaining capacity, or overall battery health.

The visible result is `Good`, `Okay`, `Poor`, or `Not Available`. A tooltip exposes the underlying measurements, confidence, load context, and limitations. This plan records the feature only; it does not authorize implementation during the Airframe 1.0 cycle.

## Think Before Coding

- Use only the observed voltage/current progression.
- Never call the result internal resistance or Battery Health.
- Interpret the rating only under the load observed in this flight.
- Temperature, charge state, chemistry, capacity, connectors, wiring, flight style, and sensor calibration remain explicit limitations.
- Require scaled battery voltage and real logged current. Missing or virtual current is unsupported.
- Use exact main-frame data rather than the decimated scan overview.
- Treat the initial rating thresholds as provisional, versioned product thresholds.

## Metric Definition

For every qualifying load event:

- `V_before`: median voltage during the 200 ms baseline window ending 40 ms before load onset.
- `V_loaded`: fifth-percentile voltage while the high-load excursion is active.
- `V_recovered`: median voltage during the 200 ms recovery window beginning 100 ms after current returns near baseline.
- `Sag Depth = V_before - V_loaded`.
- `Sag Depth % = Sag Depth / V_before * 100`.
- `Recovery = clamp((V_recovered - V_loaded) / Sag Depth, 0...1)`.
- `Sag Score = Sag Depth % * Recovery`.

A higher Sag Score means a stronger temporary voltage collapse. For example, `16.4 V -> 14.8 V -> 16.2 V` produces a `1.6 V` Sag Depth, `87.5%` Recovery, and an approximately `8.5%` Sag Score.

## Event Detection

1. Decode `vbatLatest`/`vbat` and `amperageLatest`/`amperage` chunk by chunk through the existing indexed Reader API.
2. Convert values through the existing Reader presentation and scaling rules.
3. Reject non-finite values, non-positive voltage, and unusable current.
4. Split processing at non-monotonic timestamps and recorded data gaps.
5. Collapse repeated firmware sensor values into 20 ms buckets using the last valid paired sample.
6. Apply an independent three-bucket median filter to voltage and current.
7. Calculate flight-current `P10`, `P90`, and `P95`.
8. Require each candidate to:
   - reach at least `P90` current;
   - rise at least `max(0.5 A, 20% * (P95 - P10))` above its pre-event median;
   - remain loaded for `100 ms...2 s`;
   - return within 25% of the detected current rise above baseline within 2 seconds;
   - exhibit at least `0.03 V` positive Sag Depth;
   - avoid time reversals, data gaps, arm boundaries, and disarm boundaries.
9. Cluster candidates whose onsets are less than 500 ms apart and retain the candidate with the largest current rise.
10. Rank accepted events by current rise and retain at most the strongest ten.
11. Require at least three accepted events spanning at least two flight-time quartiles. Otherwise return `Not Available`.

## Aggregation And Rating

- `Typical` is the median of the retained event values.
- `Worst` is the retained event with the highest Sag Score.
- Typical establishes the base rating:
  - `Good`: below `5%`.
  - `Okay`: `5%` through below `10%`.
  - `Poor`: `10%` or higher.
- Worst may downgrade the base rating by at most one category:
  - Typical Good plus Worst Okay or Poor becomes Okay.
  - Typical Okay plus Worst Poor becomes Poor.
  - Typical Poor remains Poor.

This conservative combination prevents one event from moving a normally Good result directly to Poor while retaining meaningful worst-case evidence.

## Confidence

Calculate the median absolute deviation over retained event scores.

- `High` requires at least eight events, coverage of at least three flight-time quartiles, and score MAD no greater than `max(1 percentage point, 25% of Typical)`.
- `Medium` requires at least three events, coverage of at least two quartiles, and score MAD no greater than `max(2 percentage points, 50% of Typical)`.
- Anything weaker returns `Not Available` with an unstable-evidence reason.

Confidence describes repeatability of the observed events, not physical sensor accuracy.

## Public Interfaces And Types

Add to `BlackboxAnalysis`:

- `AnalysisBatterySag`
  - `Result`: `available(Report)` or `unavailable(UnavailableReason)`.
  - `Report`: algorithm version, rating, confidence, accepted event count, Typical summary, and Worst summary.
  - `Summary`: Sag Score, Sag Depth, Recovery, before/loaded/recovered pack voltage, baseline/peak/delta current, load duration, and event time.
  - `Rating`: `good`, `okay`, `poor`.
  - `Confidence`: `medium`, `high`.
  - `UnavailableReason`: missing voltage, missing current, unscaled voltage, unscaled current, insufficient duration, insufficient load events, unstable evidence, or analysis limit exceeded.
- `BlackboxAnalysisWorkspace.batterySag(using:) throws -> AnalysisBatterySag.Result`.

The method remains synchronous, cancellable, off-main, and uses the supplied `DecodedLogFlightInfo` index. No Reader format, document schema, selectable-series, automatic-tag, or health-finding API changes are required.

## Simplicity First

- Add exactly one visible Power-card row.
- Do not add a chart, battery profile, guided test, history, or cross-flight comparison.
- Do not add a universal Battery Health percentage.
- Reuse existing field scaling, indexed chunk decoding, `ProcessingActivityCounter`, Power card, `KeyValueRow`, and `overviewTooltip`.
- Keep calculation independent from SwiftUI and localization.

## UI Contract

- Add `Sag Score` to the existing Power card.
- Omit the row when voltage or current is not logged.
- Show a loading value while supported data is being analyzed.
- Show `Good`, `Okay`, or `Poor` when evidence is available.
- Show `Not Available` when the fields exist but usable evidence does not.
- Use semantic green, yellow, and red presentation consistent with existing Overview status rows.
- Add no new card action or sheet.

The tooltip contains:

- numeric Typical and Worst Sag Scores;
- Typical and Worst Sag Depth in pack volts and, when cell count is usable, volts per cell;
- Typical and Worst Recovery;
- peak current, current rise, and load duration;
- accepted event count and confidence;
- a concise statement that higher scores mean stronger temporary sag under the observed load;
- an explicit statement that this is not internal resistance or Battery Health;
- dependence on load, charge state, temperature, wiring, and sensor calibration.

The accessibility value combines the visible rating with the essential evidence and limitation. Use the existing `PowerCard` and other Overview status rows as production UI references. Extend the existing debug preview with Good, Okay, Poor, and Not Available states.

## Processing, Ownership, And Cache

- Run analysis through the document's `ProcessingActivityCounter` at utility priority.
- Check cancellation between decoded chunks and during event preparation.
- Keep at most 180,000 prepared 20 ms buckets; return `analysisLimitExceeded` beyond that bound.
- Add OS-cache dataset `battery-sag`, static version `1`, keyed by source SHA-256, segment index, and algorithm version.
- Keep raw-log results only in document-scoped memory.
- Store no result in `.airframe` document metadata.
- Clear workspace-owned RAM and pending work during terminal document shutdown.
- Reject late publication and cache writes after close.
- Bump both analysis algorithm identity and persistent dataset version when thresholds or mathematics change.

## Surgical Changes

Expected implementation areas:

- `BlackboxAnalysis/BatterySag/` for pure calculation and types.
- Focused `BlackboxAnalysis` tests and synthetic fixtures.
- `PersistentDerivedDatasetCache` for the new dataset.
- Document-scoped result publication beside existing Overview/health result ownership.
- `OverviewContainer` for loading, cancellation, and cache coordination.
- `PowerCard` for the single row and tooltip.
- `AirframeCaptions` and String Catalog entries for all visible, tooltip, unavailable, confidence, and accessibility text.

Do not refactor unrelated Power rows, Health checks, automatic tags, Reader scanning, or document persistence.

## Goal-Driven Execution

### Domain Tests

- Known synthetic sag/recovery produces the expected score.
- Large drop with nearly complete recovery scores strongly.
- Large drop with little recovery produces a low temporary-sag score.
- No voltage response produces no false Poor rating.
- Recovery clamps to `0...100%`.
- Repeated 50 Hz sensor values in faster Blackbox frames do not overweight samples.
- Quantized voltage and isolated noisy samples do not become Worst events.
- Long sustained load without recovery is rejected.
- Overlapping events retain only the strongest current rise.
- Gaps, time reversals, arm, and disarm boundaries split events.
- Fewer than three events returns `Not Available`.
- Confidence boundaries and dispersion gates are exact.
- Rating boundaries cover values immediately below, at, and above `5%` and `10%`.
- Conservative Worst downgrading covers every category combination.
- Cancellation stops chunk processing.
- The bucket limit fails deterministically without unbounded allocation.

### Integration And UI Tests

- Modern and legacy battery field names work when scaling is known.
- Missing or unscaled fields return the correct unavailable reason.
- Reader limits remain enforced.
- Cache hits restore the exact semantic report; version mismatch recomputes safely.
- Raw logs never write persistent Sag results.
- Document shutdown prevents late publication.
- Good, Okay, Poor, loading, and Not Available render correctly as exactly one Power-card row.
- Tooltip and accessibility contain evidence, load context, confidence, and limitations.
- Per-cell Sag appears only with a usable cell count.
- Dynamic Type, VoiceOver, narrow iPad width, and macOS layout remain usable.
- Existing calibration behavior and Power rows remain unchanged.

### Acceptance

- Validate against synthetic ground truth and manually inspected real load events.
- Exercise representative low-current, high-current, smooth, aggressive, short, and long logs.
- Profile a representative 15-minute log on iPadOS and macOS.
- Confirm source-sized work runs once per semantic identity and off-main.
- Confirm reopening uses the cache and document close leaves no active work or retained results.
- Record `5%` and `10%` as provisional version-1 thresholds requiring later evidence-based review.

## Assumptions And Defaults

- Current scope is a per-log observed Sag Score.
- Cross-flight battery identity, trend history, and Battery Health are out of scope.
- Normal flight logs are used; no guided battery test is introduced.
- Typical and Worst are retained, but one conservatively combined category is visible.
- Higher Sag Score is worse.
- User-facing English ratings are `Good`, `Okay`, and `Poor`.
- Airframe 1.0 explicitly excludes this feature.
