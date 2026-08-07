# iPad Readiness Audit

- Status: automated implementation verification complete; manual device and accessibility acceptance remains
- Scope: Airframe 1.0 feature-freeze adaptation
- Date: 2026-08-07
- Default platform: iPadOS; macOS is a frozen regression target

## Interaction Contract

Existing interactive analysis surfaces use the following iPadOS semantics:

| Input | Graph | Timeline / Map Timeline | Spectrum | Frequency Response |
| --- | --- | --- | --- | --- |
| Tap | Select time | Select time | Select measurement | Select measurement |
| One-finger drag | Move selected time under the finger | Scrub time | Move measurement | Move measurement |
| Pinch | Zoom around the touch anchor | Not added; no existing timeline viewport | Zoom around the touch anchor | Only where the existing surface supports zoom |
| Two-finger drag | Pan the visible time window | Not added; no existing timeline viewport | Pan the zoomed frequency window | Only where the existing surface supports pan |
| Double tap | Show the complete time range | Not added; no existing timeline viewport | Reset frequency viewport | Only where the existing surface supports reset |

Selections remain visible after touch end. Native MapKit gestures remain untouched. Static Craft, Step Response, loading, background, guide, and coverage canvases remain noninteractive.

## P0

### iPad target did not compile

- Finding: `FlightControllerConnectionFlow` switched over macOS-only `Device.Connection.usb` from the iOS build.
- Impact: no iPad build or runtime validation was possible.
- Fix: compile the USB case and its USB-specific app tests only on macOS. Bluetooth behavior remains available on both platforms.

## P1

### Document navigation could strand the user

- Finding: selecting a log persisted `.detailOnly`, hid the Sidebar, and exposed no explicit route to Home.
- Impact: logs and the start screen could become unreachable, especially in compact or resized iPad windows; persisted column state could also leak across platforms.
- Fix: keep iPad column visibility and preferred compact column transient, add an explicit Logs action, route all iOS launches through `HomeView`, and add a Home action that uses the existing flush/`UIDocument.close` lifecycle. macOS retains its existing persisted split-view state and widths.

### Navigation chrome consumed too much compact width

- Finding: the document name used the large navigation-title presentation and the six-mode segmented picker always requested its full width.
- Impact: small iPads, portrait orientation, Split View, and Stage Manager windows had insufficient content width.
- Fix: use an inline iOS title and `ViewThatFits` to retain the segmented picker when it fits and fall back to a native menu when it does not.

### Canvas touch semantics differed by surface

- Finding: Graph inherited desktop-style gesture wiring, Spectrum inspection disappeared on touch end, and two-finger viewport panning was not consistently isolated from one-finger inspection.
- Impact: users had to relearn gestures and could not read a measurement after lifting their finger.
- Fix: use an iOS-native recognizer layer for Graph, split Spectrum pointer implementations by platform, preserve touch selections, and keep one-finger selection separate from two-finger viewport movement. Existing exact-cursor, persistence-suspension, cache, and static-render invalidation boundaries remain in place.

### Important controls had undersized touch targets

- Finding: playback, timeline-toolbar, preset-management, Graph setup, and marker-chip actions had hit regions below 44 points. Preset rename relied on a desktop double click.
- Impact: reduced touch accuracy and discoverability; some actions were difficult with VoiceOver or motor impairments.
- Fix: apply iOS-only 44-point hit regions, use native buttons for non-positional taps, provide an explicit iPad rename action, and retain existing macOS dimensions and double-click behavior.

## P2 / Deferred

- Visually inspect dense Graph/Spectrum marker layouts after the iOS-only 44-point marker collision geometry change.
- Validate every inspector at the largest Dynamic Type sizes; fixed analytical layouts may still require targeted wrapping or scrolling work.
- Audit remaining pre-existing inline accessibility/help strings outside the touched interaction paths and migrate them to `AirframeCaptions` in a bounded localization pass.
- Validate hardware keyboard focus order through Sidebar, toolbar, inspector, Timeline, and Canvas accessibility elements.
- Perform physical-device gesture acceptance, including accidental palm/multi-touch input and Apple Pencil behavior. Pencil-specific features are outside the feature freeze.
- Validate document close/background behavior with iCloud Drive and third-party document providers; simulator success does not satisfy provider lifecycle gates.
- Profile aggressive Graph scrubbing and simultaneous Spectrum pinch/pan on representative long logs. No new processing, persistence, hashing, or bitmap preparation belongs in gesture callbacks.
- The Paywall remains approved only for the separate pre-release step.

## Device And Window Matrix

Test portrait and landscape where applicable:

- iPad mini: 744 × 1133 points
- iPad: 820 × 1180 points
- iPad Pro 11-inch: 834 × 1210 points
- iPad Pro 13-inch: 1032 × 1376 points
- narrow, intermediate, and wide resizable windows under Split View and Stage Manager

For each size, verify Home, open-document state, Sidebar reveal, all view-picker modes, inspector presentation, Timeline expanded/collapsed states, and long document/log names.

## Manual Accessibility Checklist

- Enable VoiceOver and confirm Home, Logs, mode picker/menu, playback, Timeline range, preset rename, Graph setup, and marker interactions have meaningful roles and labels.
- Confirm Timeline and Canvas adjustable actions announce current values and leave the exact final position after adjustment.
- Use the largest accessibility text size and confirm no required action becomes unreachable.
- Navigate the complete document surface with a hardware keyboard and verify predictable focus order.
- Confirm state is not communicated only by color in selections, disabled actions, and processing indicators.
- Enable Reduce Motion and verify existing animated indicators continue to honor the preference.

Expected result: behavior changes only on iPadOS except for localized accessibility text and platform-neutral test coverage. macOS geometry, hover, trackpad, double-click, navigation, and document behavior remain unchanged.

## Regression Risk

- Highest risk: competing native/SwiftUI recognizers around Graph and Spectrum. Verify one-finger selection never fires during a two-finger pan and pinch can coexist only with the intended pan recognizer.
- Medium risk: compact toolbar composition and system `NavigationSplitView` behavior vary by window width. Verify both visible Sidebar and collapsed-stack states.
- Medium risk: larger iOS marker hit regions can change collision placement despite unchanged chip visuals.
- Low risk: macOS code is retained behind explicit platform branches, but both a macOS build and pointer/hover smoke test remain mandatory.

## Verification Record

- AirframeCaptions package tests: 39 tests passed.
- AirframeUI package tests: 154 tests passed across 18 suites.
- Focused iPad Graph interaction policy tests: 18 tests passed.
- iPad mini (744 × 1133) Debug build: passed after final integration.
- iPad Pro 13-inch Debug build: passed during the integrated implementation pass; the final toolbar closure delta is also covered by the later iPad mini build.
- macOS Debug regression build: passed after final integration.
- iOS navigation UI test: passed on iPad mini; it verifies document launch, the explicit Logs action, Sidebar reachability, Home action, and return to `HomeView`.
- iPad mini portrait render: inspected from the UI-test recording; Home, Logs, adaptive mode control, Presets, and Inspector controls fit the top bar while the Sidebar and detail remain visible.
- `git diff --check` and String Catalog JSON validation: passed after final integration.
- Rendered visual and physical-device acceptance: manual gate
