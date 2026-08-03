# Feature Showcase

## Primary Features

The first six features should anchor the Discord showcase. The remaining product details are useful for the future website.

1. **At-a-glance flight overview**
   - Flight, power, GPS, hardware, firmware, Blackbox configuration, recorded data, notes, and log checks in one dashboard.
   - Best first product screenshot because it explains Airframe without specialist interaction.

2. **Interactive graph analysis and playback**
   - Inspect selected raw and derived signals on a shared flight timeline.
   - Configure graph sections and fields, inspect events, and use the craft visualization to relate traces to the aircraft.
   - Playback and scrubbing keep analytical views aligned to the same flight position.

3. **Noise analysis in Spectrum**
   - Frequency, Frequency vs Throttle, and Frequency vs RPM views.
   - Inspect gyro, D-term, motors, PID-related signals, and filter behavior, including RPM-notch overlays where available.
   - Filter Guides relate measured noise to craft-motion, prop-wash and control, and motor-noise ranges derived from the aircraft profile, with P90 references and configured filter curves in the same view.

4. **Step Response tuning comparison**
   - Compare Roll, Pitch, and Yaw response.
   - Attach reference logs for side-by-side tuning comparisons with stable trace colors and PID tune context.

5. **Native GPS flight map — beta**
   - View the route, Home, heading, flight events, and an altitude or speed profile.
   - Switch between available GPS altitude, barometer altitude, GPS speed, and distance-from-home timelines.
   - Present Map as an active beta feature whose core experience works but is still being refined.

6. **Flight Controller Import Assistant**
   - Connect through a USB cable, Bluetooth, or the SpeedyBee Adapter 3.
   - Import through Direct transfer, USB Mass Storage, or the Adapter 3's Wi-Fi connection when supported by the setup.
   - Bluetooth and SpeedyBee Adapter 3 support enable direct flight-controller import on iOS devices.
   - Optionally keep Betaflight settings with the imported logs and remove logs from the controller after a confirmed import.

## Website Details

7. **Airframe documents and multi-log organization**
   - Keep several logs, names, notes, configuration, and analysis state together in one `.airframe` document.
   - Automatic log tags help distinguish flights. Individual logs can be hidden without deleting their data and restored later.

8. **Native, local, and private**
   - A native Swift app for macOS, with iPhone and iPad versions planned to follow later.
   - The iOS interface still needs dedicated adaptation for smaller displays and touch interaction before release.
   - Blackbox logs and Airframe documents are processed locally. Airframe contains no analytics, advertising, or tracking services.

9. **Spectrum Filter Guides**
   - Show measured noise, expected frequency regions, P90 references, low-pass filters, and RPM-notch harmonics together.
   - Use the aircraft profile and recorded Betaflight configuration to help answer whether the active filters target the relevant noise.

These are valuable trust and workflow details for the website, but do not need standalone Discord posts in the first showcase.

## Founder Story

- Airframe started while tuning from a camping chair at the field.
- The existing workflow felt slow and old-fashioned when it should have made rapid tuning iterations easy.
- As a macOS and iOS developer, Daniel decided it was time to build a modern native tool for the platforms he uses.
- The original goals were simple: display Blackbox logs quickly in a modern interface and import them directly from the flight controller.
- Use this story as the opening narrative. It gives the feature sequence a reason to exist: fast analysis first, frictionless import second.

## Development Status

- Airframe is still in active development.
- Not every feature planned for version 1.0 is available yet.
- Airframe may not yet include every analysis or view available in other Blackbox tools.
- The current scope reflects the capabilities Daniel genuinely needed for his own tuning and that already proved useful in practice.
- State this in the Discord introduction and closing post so the current showcase is not mistaken for the final 1.0 scope.
- Invite readers to suggest analyses, views, and workflows that would help them. Feedback from real flights should help shape priorities.

## Supporting Features

Mention these within primary posts or use them in later follow-ups:

- Raw `.bbl` and `.bfl` log support.
- Table view for exact frame values.
- Multiple Blackbox segments in one source file.
- Automatic detection and presentation of flight events.
- Health and data-quality findings.
- Persistent per-document view state and cached analysis.
- Notes stored with Airframe documents.
- Read-only handling of raw Betaflight logs.
- CSV and diagnostic workflows through the Airframe CLI for advanced users.

## Defer From the First Showcase

- Presets: currently hidden pending a UX redesign.
- GPX export, video sync, bookmarks, Quick Look, and other backlog ideas: not implemented.
- A finished-product claim for Map: it is still beta. Showcase the useful current experience honestly and avoid making continuous route playback the headline while its rendering is still being refined.
- Low-level container design, recovery, and compaction: valuable trust material for a later technical article, not the opening product story.
- Exact compatibility promises across every Betaflight version or flight controller: state only what has been verified.
