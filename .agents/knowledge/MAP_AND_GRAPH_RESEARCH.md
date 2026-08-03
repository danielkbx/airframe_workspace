# Map and Graph Research

- Status: active
- Last reviewed: 2026-08-01
- Scope: native MapKit feasibility, flight-route semantics, and graph-section layout evidence
- Normative decisions: `../MEMORY.md`
- Related implementation: Airframe Map and Graph views

## Evidence Matrix

| ID | Claim | Source | Grade | Scope | Airframe impact | Status |
|---|---|---|---|---|---|---|
| MGR-001 | SwiftUI MapKit supports bound camera, polylines, custom annotations, and standard/imagery styles on target platforms. | Apple SDK and local implementation | A | iOS/macOS 26 targets | No external map dependency is required. | verified |
| MGR-002 | Logged historical position must use a custom annotation rather than device user-location APIs. | Product semantics | A | Flight-log playback | Avoid live-location permission and semantic confusion. | verified |
| MGR-003 | Reference graph layouts use ordered sections sharing time while maintaining independent Y domains. | BLV | B | Inspected revision | Persist only ordered section names/series IDs; native rendering owns layout. | verified |

## Native Flight Map

Camera initialization can use the complete route `MKMapRect`; leaving camera state untouched during cursor changes preserves native pan/zoom. Betaflight GPS altitude and Home altitude are decimeters and ground course decidegrees; Reader converts them at its public scan boundary. Product decisions for route eligibility, playback, event markers, and source selection remain normative in `../MEMORY.md`.

## Graph Layout

The reference renderer accepts ordered graph definitions with labels, field lists, and optional height weights, divides vertical space, and shares one document time domain. Every section owns its Y grid/projection. Airframe intentionally retains only ordered semantic series IDs and equal-height native sections initially; styling, smoothing, and weights remain out of persisted state. New Graph setups mirror the small upstream default of Motors and Gyros, while Table keeps separate defaults.

Reference PID terms and derived sums are shown as mixer-authority percent by dividing logged values by 10. They may be negative or exceed 100 before downstream limiting; “100%” is not a bounded UI percentage or gain percentage.

## Source Register

| Source ID | Title | Author/project | Version/date | URL or local path | Accessed | Notes |
|---|---|---|---|---|---|---|
| APPLE-MAP | MapKit/SwiftUI Map APIs | Apple | Xcode 26 target SDK | Apple SDK/documentation | 2026-08-01 | Primary platform API evidence |
| BLV | Graph and map implementation | Betaflight Blackbox Explorer | commit `a039b74492cdbaca6f94852a7958df1c2dc064b1` | `blackbox-log-viewer/src/graph_config.js`, `grapher.js`, `graph_map.js` | 2026-08-01 | Reference behavior |
| BF-SRC | GPS and PID units | Betaflight | commit `6ecfb45f938e4996fbb568b21eafa7057446a906` | `betaflight/src/main/` | 2026-08-01 | Firmware semantics |

