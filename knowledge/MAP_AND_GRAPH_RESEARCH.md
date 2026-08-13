# Map and Graph Research

- Status: active
- Last reviewed: 2026-08-13
- Scope: native MapKit feasibility and limitations, flight-route semantics, and graph-section layout evidence
- Normative decisions: `../.agents/MEMORY.md`
- Related implementation: Airframe Map and Graph views

## Evidence Matrix

| ID | Claim | Source | Grade | Scope | Airframe impact | Status |
|---|---|---|---|---|---|---|
| MGR-001 | SwiftUI MapKit supports bound camera, polylines, custom annotations, and standard/imagery styles on target platforms. | Apple SDK and local implementation | A | iOS/macOS 26 targets | No external map dependency is required. | verified |
| MGR-002 | Logged historical position must use a custom annotation rather than device user-location APIs. | Product semantics | A | Flight-log playback | Avoid live-location permission and semantic confusion. | verified |
| MGR-003 | Reference graph layouts use ordered sections sharing time while maintaining independent Y domains. | BLV | B | Inspected revision | Persist only ordered section names/series IDs; native rendering owns layout. | verified |
| MGR-004 | Before the Map Timeline invalidation fix, a SwiftUI `MapPolyline` with stable structural identity did not update its rendered coordinates during continuous playback even though the view and map-content builder received the current route prefix about 20 times per second. | AF-MAP-TEST | A | Historical macOS 26.5 live Airframe test | Preserve as historical diagnostic evidence; it no longer describes post-optimization behavior. | superseded |
| MGR-005 | Before the Map Timeline invalidation fix, forcing a new polyline identity for each route update, including a small changing tail over static chunks, caused MapKit overlay replacement to lag by many seconds. | AF-MAP-TEST | A | Historical macOS 26.5 live Airframe test | Do not revive identity/chunking experiments without new contrary evidence. | superseded |
| MGR-006 | An `MKMapView` representable could update overlays directly and keep route overlays below annotations. | MapKit API plus AF-MAP-TEST inference | D | Rejected replacement | The bridge is unnecessary after post-optimization Debug verification; keep the native SwiftUI Map implementation. | retired |
| MGR-007 | A logged firmware quaternion can be grossly inconsistent with physical tilt even while its fields decode correctly. At about 339.6 seconds in Barney `LOG00006.BFL` (Betaflight 2025.12.5), the quaternion implies 85.6° total tilt while the simultaneous accelerometer direction implies 23.2°. Blackbox Explorer's 3D Craft also appears almost edge-on at 339.203 seconds because it consumes the same quaternion without a plausibility gate. | AF-BARNEY-ATTITUDE and BLV source | A | One real magnetometer-equipped flight with suspected bad compass calibration | Presence of `imuQuaternion` is not sufficient evidence that Map or Graph roll/pitch is trustworthy; add a conservative source-consistency policy before relying on it visually. | verified |

## Native Flight Map

Camera initialization can use the complete route `MKMapRect`; leaving camera state untouched during cursor changes preserves native pan/zoom. Betaflight GPS altitude and Home altitude are decimeters and ground course decidegrees; Reader converts them at its public scan boundary. Product decisions for route eligibility, playback, event markers, and source selection remain normative in `../.agents/MEMORY.md`.

At `mainFrameTime` 1,235,145,894 in Barney `LOG00006.BFL`, decoded quaternion components `(x, y, z, w) = (-0.63735, 0.23457, 0.72805, 0.09333)` produce 70.8° roll, 76.4° pitch, and 85.6° total tilt. The simultaneous normalized `accSmooth` vector `(-0.1282, -0.3727, 0.9191)` is only 23.2° from upright. The Map's top-down renderer preserves the quaternion's `up.z`, so its almost edge-on Craft is an accurate projection of an untrustworthy attitude source rather than a heading or projection error. This one sample does not justify using raw acceleration as attitude during dynamic flight; it demonstrates the need for sustained consistency gating or an independently fused gyro/accelerometer fallback.

The implemented independent-policy replay over the complete 61,251-sample log selects the gyro/accelerometer candidate at relative time 339.596 seconds: direct firmware tilt remains 85.622°, while refined tilt is 31.340° and the aggregate timeline source is mixed. The policy requires sustained qualified evidence and never substitutes a raw accelerometer vector as the rendered attitude. High-rate unqualified gaps up to 0.25 seconds preserve accumulated evidence without contributing to it; longer gaps or qualified contradictory samples reset the switch evidence.

Blackbox Explorer follows the same source priority. `flightlog.js` reconstructs positive `w` from logged `imuQuaternion[0...2]`, derives Euler roll/pitch/heading directly, and invokes its gyro/accelerometer IMU estimator only when the quaternion is absent. `craft_3d.js` applies `-pitch` around Three.js X and `roll` around Y; yaw is intentionally commented out. It performs no quaternion-versus-gravity consistency check. Therefore its almost edge-on Craft at 05:39.203 corroborates Airframe's decode rather than validating the physical attitude.

### SwiftUI MapPolyline Playback Limitation

The 2026-07-31 live diagnosis separated Airframe state publication from MapKit rendering. `LogPlaybackController`, `Surface.body`, and the map-content builder all advanced with the correct point index while the visible route remained stale. A stable `MapPolyline` identity failed to adopt new coordinates; changing identity forced remove/add work that accumulated seconds of lag. The existing 2,048-point decimation was not the cause, and a Canvas overlay was rejected because the route must stay below Home and Event annotations. This evidence describes the pre-optimization implementation state only.

On 2026-08-06, after Map Timeline series/domain/grid preparation was hoisted and current-position observation was isolated to its cursor leaf, a 15-second scrub trace showed zero static Timeline work and only 132 ms in route-prefix coordinate projection. The user verified that both the map and progressive route line are fully fluid in a macOS Debug build. The proposed `NSViewRepresentable`/`UIViewRepresentable` bridge is therefore retired: its complexity and duplicated annotation, callout, camera, styling, and accessibility behavior have no remaining user-visible performance justification.

## Graph Layout

The reference renderer accepts ordered graph definitions with labels, field lists, and optional height weights, divides vertical space, and shares one document time domain. Every section owns its Y grid/projection. Airframe intentionally retains only ordered semantic series IDs and equal-height native sections initially; styling, smoothing, and weights remain out of persisted state. New Graph setups mirror the small upstream default of Motors and Gyros, while Table keeps separate defaults.

Reference PID terms and derived sums are shown as mixer-authority percent by dividing logged values by 10. They may be negative or exceed 100 before downstream limiting; “100%” is not a bounded UI percentage or gain percentage.

## Source Register

| Source ID | Title | Author/project | Version/date | URL or local path | Accessed | Notes |
|---|---|---|---|---|---|---|
| APPLE-MAP | MapKit/SwiftUI Map APIs | Apple | Xcode 26 target SDK | Apple SDK/documentation | 2026-08-01 | Primary platform API evidence |
| BLV | Graph and map implementation | Betaflight Blackbox Explorer | commit `1222587e162fd2c881ee2ea3d74ec91c2397891d` | `upstreams/blackbox-log-viewer/src/graph_config.js`, `grapher.js`, `graph_map.js` | 2026-08-05 | Reference behavior; functional source unchanged from prior pin |
| BF-SRC | GPS and PID units | Betaflight | tag `2026.6.1`, commit `6dbc4218fd6bc33bf16ea32c670304d4f89321d5` | `upstreams/betaflight/src/main/` | 2026-08-05 | Stable firmware semantics |
| AF-MAP-TEST | Airframe SwiftUI Map playback diagnosis and post-optimization verification | Airframe local live tests | 2026-07-31 and 2026-08-06 on macOS 26.5 | Git history and local diagnostic traces; temporary instrumentation removed | 2026-08-06 | Earlier lag evidence is retained as historical context; the post-optimization Debug build is fluid and retires the bridge direction. |
| AF-BARNEY-ATTITUDE | Real-log attitude-source diagnosis | Airframe local data extraction | Barney `LOG00006.BFL`, Betaflight 2025.12.5, around 339.6 seconds | User document inspected locally; raw log SHA-256 `539b1302e0e574a87b5653a2f9d29f02e7aad9519f37241d2ea156c821b79f60` | 2026-08-13 | Firmware quaternion and simultaneous accelerometer disagree strongly; the user confirms the Craft was not near vertical. |
