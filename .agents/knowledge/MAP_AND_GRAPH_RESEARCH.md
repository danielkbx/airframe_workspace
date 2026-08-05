# Map and Graph Research

- Status: active
- Last reviewed: 2026-08-05
- Scope: native MapKit feasibility and limitations, flight-route semantics, and graph-section layout evidence
- Normative decisions: `../MEMORY.md`
- Related implementation: Airframe Map and Graph views

## Evidence Matrix

| ID | Claim | Source | Grade | Scope | Airframe impact | Status |
|---|---|---|---|---|---|---|
| MGR-001 | SwiftUI MapKit supports bound camera, polylines, custom annotations, and standard/imagery styles on target platforms. | Apple SDK and local implementation | A | iOS/macOS 26 targets | No external map dependency is required. | verified |
| MGR-002 | Logged historical position must use a custom annotation rather than device user-location APIs. | Product semantics | A | Flight-log playback | Avoid live-location permission and semantic confusion. | verified |
| MGR-003 | Reference graph layouts use ordered sections sharing time while maintaining independent Y domains. | BLV | B | Inspected revision | Persist only ordered section names/series IDs; native rendering owns layout. | verified |
| MGR-004 | A SwiftUI `MapPolyline` with stable structural identity did not update its rendered coordinates during continuous playback even though the view and map-content builder received the current route prefix about 20 times per second. | AF-MAP-TEST | A | macOS 26.5 live Airframe test | Do not rely on stable SwiftUI map-content identity for a changing route overlay. | verified |
| MGR-005 | Forcing a new polyline identity for each route update, including a small changing tail over static chunks, caused MapKit overlay replacement to lag by many seconds. Reducing the changed geometry did not remove the lag. | AF-MAP-TEST | A | macOS 26.5 live Airframe test | Further SwiftUI `Map` identity/chunking variants are not a useful implementation path. | verified |
| MGR-006 | An `MKMapView` representable can update overlays directly and keep route overlays below annotations. | MapKit API plus AF-MAP-TEST inference | A/D | Future replacement | Use native overlay/annotation ownership for the accepted fix; verify both platforms. | partially verified |

## Native Flight Map

Camera initialization can use the complete route `MKMapRect`; leaving camera state untouched during cursor changes preserves native pan/zoom. Betaflight GPS altitude and Home altitude are decimeters and ground course decidegrees; Reader converts them at its public scan boundary. Product decisions for route eligibility, playback, event markers, and source selection remain normative in `../MEMORY.md`.

### SwiftUI MapPolyline Playback Limitation

The 2026-07-31 live diagnosis separated Airframe state publication from MapKit rendering. `LogPlaybackController`, `Surface.body`, and the map-content builder all advanced with the correct point index while the visible route remained stale. A stable `MapPolyline` identity failed to adopt new coordinates; changing identity forced remove/add work that accumulated seconds of lag. The existing 2,048-point decimation was not the cause, and a Canvas overlay was rejected because the route must stay below Home and Event annotations.

The accepted future direction is to replace only `FlightMap.Surface` with `NSViewRepresentable`/`UIViewRepresentable` around `MKMapView`. Keep the current route preparation and deterministic decimation. A coordinator owns incremental completed-prefix/tail overlays, renders them below annotations, preserves standard/imagery styles and initial framing, and recreates Home, Event, position, heading, popover, and accessibility behavior. Acceptance requires the route tip to track playback at 1x and maximum rate, shorten immediately on reverse scrub, and preserve annotations/framing/styles on macOS and iOS. This is an implementation constraint, not an active task; the backlog holds the feature request.

## Graph Layout

The reference renderer accepts ordered graph definitions with labels, field lists, and optional height weights, divides vertical space, and shares one document time domain. Every section owns its Y grid/projection. Airframe intentionally retains only ordered semantic series IDs and equal-height native sections initially; styling, smoothing, and weights remain out of persisted state. New Graph setups mirror the small upstream default of Motors and Gyros, while Table keeps separate defaults.

Reference PID terms and derived sums are shown as mixer-authority percent by dividing logged values by 10. They may be negative or exceed 100 before downstream limiting; “100%” is not a bounded UI percentage or gain percentage.

## Source Register

| Source ID | Title | Author/project | Version/date | URL or local path | Accessed | Notes |
|---|---|---|---|---|---|---|
| APPLE-MAP | MapKit/SwiftUI Map APIs | Apple | Xcode 26 target SDK | Apple SDK/documentation | 2026-08-01 | Primary platform API evidence |
| BLV | Graph and map implementation | Betaflight Blackbox Explorer | commit `1222587e162fd2c881ee2ea3d74ec91c2397891d` | `blackbox-log-viewer/src/graph_config.js`, `grapher.js`, `graph_map.js` | 2026-08-05 | Reference behavior; functional source unchanged from prior pin |
| BF-SRC | GPS and PID units | Betaflight | tag `2026.6.1`, commit `6dbc4218fd6bc33bf16ea32c670304d4f89321d5` | `betaflight/src/main/` | 2026-08-05 | Stable firmware semantics |
| AF-MAP-TEST | Airframe SwiftUI Map playback diagnosis | Airframe local live test | 2026-07-31 on macOS 26.5 | Git history and prior diagnostic traces; temporary instrumentation removed | 2026-08-05 | Reproducible product observation; app-side state freshness and both identity strategies were tested |
