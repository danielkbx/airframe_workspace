# Screenshot Plan

## Shared Capture Setup

The visible flight-controller UID in `01-overview.png` and the recognizable flight location in `06-flight-map.png` are approved for publication in this specific screenshot set.

- Use the latest verified beta build on macOS for the main set.
- Use one representative flight with clean, visually interesting data. Use a GPS flight where required and a tuning flight where Spectrum or Step Response benefits.
- Use a consistent window size, ideally 1440 × 900 logical points or the closest clean 16:10 composition.
- Keep the window title, mode picker, sidebar, timeline, and inspector visible when they add context.
- Use the app's default appearance and avoid unrelated desktop content. Crop to the application window.
- Rename logs to neutral, descriptive names such as `Baseline`, `Filter Test`, and `PID Revision`.
- Remove or obscure private coordinates, filenames, paths, serial numbers, device identifiers, pilot names, and notes.
- Export PNG at native scale. Do not add text, arrows, or frames to the image; the Discord message supplies the explanation.

## Required Captures

Current status:

- Available: Overview, Graph and Playback, Spectrum, Step Response, Flight Map, Flight Controller Import.
- Build update asset: `08-build-43-filter-guides.png`, showing the new Spectrum Filter Guides with measured gyro signals, frequency regions, P90 references, and filter curves.
- This six-image set is final. No additional screenshots are planned for the Discord showcase.

### 01 — Overview

Filename: `01-overview.png`

Capture:

- Select a log with enough metadata to fill Flight, GPS, Power, Flight Controller, Hardware, Blackbox, and Checks.
- Scroll so the strongest six to eight cards are visible together.
- Keep the selected log and its automatic tags visible in the sidebar.
- Avoid open sheets or hover states.

Purpose: the clearest broad introduction to the app.

### 02 — Graph and Playback

Filename: `02-graph-playback.png`

Capture:

- Show Graph with three or four readable sections, for example Gyro, Setpoint, Motors, and PID Sum.
- Position the cursor at an interesting maneuver and leave one or two event chips visible.
- Show the shared timeline and playback controls.
- Open the inspector far enough to include the craft visualization, but do not squeeze the graph labels.

Purpose: show how a flight becomes an explorable timeline rather than a static file.

### 04 — Spectrum

Filename: `04-spectrum-frequency.png`

Capture:

- Prefer Frequency vs RPM for the most distinctive image; use Frequency vs Throttle if the chosen log is clearer there.
- Select a gyro or D-term signal with visible structure.
- Enable relevant RPM-notch overlays when the log supports them.
- Keep the spectrum mode, selected signal, color scale, and filter controls visible.

Purpose: explain where noise occurs and how it relates to operating conditions.

### 05 — Step Response Comparison

Filename: `05-step-response-comparison.png`

Capture:

- Attach two or three intentionally named logs, such as `Baseline`, `Revision 1`, and `Revision 2`.
- Show all three Roll, Pitch, and Yaw panes.
- Keep the trace list and PID tune columns visible.
- Choose logs whose curves are visibly different without becoming cluttered.

Purpose: make iterative tune comparison immediately understandable.

### 06 — Flight Map

Filename: `06-flight-map.png`

Capture:

- Use a GPS log with a recognizable route and useful altitude variation.
- Set the flight position partway through the route.
- Show Home, current position with heading, and a small number of event markers.
- Keep the altitude profile visible and choose the clearest available source.
- Open one event popover only if it does not obscure the route.
- Capture a static state; do not base the showcase on live route playback.

Purpose: connect log data with the physical flight while presenting Map as a promising beta feature.

### 07 — Flight Controller Import

Filename: `07-flight-controller-import.png`

Capture:

- Use a real, supported controller or the polished mock state if public hardware details must remain private.
- Prefer the connected-device summary or method-selection step over a transient progress screen.
- Capture the method-selection step with Direct, Mass Storage, and Wi-Fi visible only when the connected hardware legitimately supports them.
- Keep the assistant steps, board, firmware, Blackbox storage, and available import methods visible if the layout allows it.
- Do not expose adapter MAC addresses, Bluetooth identifiers, serials, or Wi-Fi details.

Purpose: show that logs can enter Airframe without a manual file-management detour.

## Capture Checklist

- Correct current app version and beta badge state.
- No debug overlays, selection rectangles, tooltips, or transient loading indicators.
- No clipped labels or unnecessary scrollbars.
- No private data.
- UI language is consistent across the set.
- Image remains legible when displayed around 900 px wide in Discord.
- Each image still makes sense when viewed without adjacent images.
