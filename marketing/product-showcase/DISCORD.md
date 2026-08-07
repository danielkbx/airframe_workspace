# Discord Showcase Copy

Each numbered section is one independent Discord message followed by its image. Keep the image immediately after the matching text. The copy is deliberately short enough to work without a designed layout.

## Early Access Update — Build 43

**Build 43 is available**

The highlight of this build is the new Filter Guides in Spectrum. They place craft motion, prop wash and control, motor-noise ranges, P90 references, and the configured filter and RPM-notch curves directly alongside the measured spectrum. This makes it easier to see not only where noise occurs, but whether the filters are targeting the right areas.

Build 43 also adds aircraft settings, center-of-gravity diagnostics, battery cell information, and several state-restoration fixes.

Image: `08-build-43-filter-guides.png`

## Early Access Update — Build 47

**CHIRP analysis is now in Airframe**

Build 47 adds a dedicated frequency-response analysis for Betaflight CHIRP flights. Airframe detects recorded CHIRP sweeps automatically and presents the response, phase, sensitivity, and derived step response for Roll, Pitch, and Yaw.

Tune Score summarizes stability margin, robustness, damping, and tracking fidelity, together with its confidence and the supporting measurements for each axis. It is intended to make the recorded response easier to interpret while keeping the underlying evidence visible.

The Spectrogram view shows how the measured signal follows the expected sweep and can highlight its start, end, and harmonics. Together, the two views show both the resulting frequency response and the quality of the evidence behind it.

Tune Score is an assessment of the recorded flight, not a tuning recommendation.

Images: `09-build-47-chirp-response.png`, followed by `10-build-47-chirp-spectrogram.png`

## 00 — The Story Behind Airframe

**Airframe**

Airframe started in a camping chair at the flying field.

While tuning, I got increasingly frustrated with the existing workflow. The tools felt slow and old-fashioned at exactly the moment when I wanted to inspect a log, make a change, and get back in the air.

I’m a macOS and iOS developer, so I decided it was time to build the tool I wanted to use: a modern, fast Blackbox log analyzer that can also import logs directly from the flight controller.

That became Airframe. Over the next few posts, I’ll show what it can already do.

Airframe is still in active development. It does not yet offer every view or type of analysis found in other tools, and not every feature planned for 1.0 is available yet. So far, I have focused on the things I genuinely needed for my own tuning—and they have already helped me a lot.

I’ll keep this channel updated whenever there are major changes or new features worth showing.

Image: `01-overview.png`

## 01 — Overview

**A summary of the recorded flight**

The Overview gathers the most relevant context from a Blackbox log in one place: flight timing, power, GPS, hardware, firmware, Blackbox configuration, recorded data, and detected issues.

Its purpose is to establish what happened, how the flight controller was configured, and whether the log is suitable for a deeper analysis.

Image: `01-overview.png`

## 02 — Graph and Playback

**Understanding what happened over time**

Graph places raw and derived signals on a shared flight timeline. Setpoint and gyro behavior, motor output, flight events, and other recorded values can be viewed at the same point in time.

Configurable graph sections keep related signals together. Playback, the timeline, and the craft visualization provide context for how the aircraft behaved during a maneuver.

Image: `02-graph-playback.png`

## 03 — Spectrum

**Finding where noise occurs**

Spectrum shows the frequency content recorded during a flight. The frequency view provides an overall picture, while throttle- and RPM-based heatmaps reveal where noise appears across the operating range.

Filter curves and RPM-notch information can be placed alongside the measured signals when the required configuration is available. This makes it easier to relate a filter setup to the noise it is intended to address.

Image: `04-spectrum-frequency.png`

## 04 — Step Response

**Evaluating the response of a tune**

Step Response describes how Roll, Pitch, and Yaw react to setpoint changes. It helps reveal overshoot, settling behavior, and differences between the three axes.

Reference logs place several tuning revisions in the same view, together with their recorded PID values. The comparison is intended to show whether a change produced a measurable improvement rather than merely a different curve.

Image: `05-step-response-comparison.png`

## 05 — Flight Map Beta

**Adding spatial context to a flight — beta**

Map relates the Blackbox timeline to the physical route of a GPS-equipped flight. It shows the recorded path, Home, heading, and flight events together with a synchronized altitude, speed, or distance profile.

This helps identify where an event or change in the log occurred. Map is still a beta feature, and its presentation and playback behavior are being refined.

Image: `06-flight-map.png`

## 06 — Flight Controller Import

**Reducing the steps between flying and analysis**

The Flight Controller Import Assistant is intended to remove the manual file-management steps between a flight and its analysis. Airframe supports connections through a USB cable, Bluetooth, and the SpeedyBee Adapter 3. Depending on the controller and its Blackbox storage, transfer is handled directly, through USB Mass Storage, or through the Adapter 3’s Wi-Fi connection.

Betaflight settings can be stored with the imported logs. This preserves the configuration that produced the recorded behavior and makes later comparisons more meaningful.

Bluetooth and the SpeedyBee Adapter 3 provide the connection paths needed for flight-controller import on iOS devices. The iOS version of Airframe will arrive later, because smaller displays and touch interaction still require more dedicated adaptation.

Image: `07-flight-controller-import.png`

## 07 — But What About the Money?

**No subscriptions and no recurring costs**

The final model for funding Airframe has not been decided yet. What is already clear is that there will be no subscription and no recurring cost. Some capabilities will probably require a one-time purchase, similar to a Pro version. Possible candidates are direct communication with the flight controller and advanced analysis features that are valuable to a relatively small group of users. The exact scope and price are still open.

## 08 — Closing

**The direction of Airframe**

The goal behind Airframe is still the same as it was in that camping chair: reduce the friction around Blackbox analysis and make the recorded behavior easier to understand between flights.

Airframe is still in active development, and not every feature planned for 1.0 is available yet. Suggestions for useful analyses, views, or workflows are welcome. Feedback from real flights will help decide what to refine and build next on the way to the first full release.

Image: reuse `02-graph-playback.png` or `07-flight-controller-import.png`

## Website-Only Copy — Airframe Documents

**Keep the complete investigation together.**

An Airframe document can hold multiple logs, their names and notes, imported configuration, and analysis state. Automatic tags help distinguish flights, while individual logs can be hidden without deleting their data and restored whenever they are needed again.

It turns a folder of raw files into a reusable analysis workspace.

## Website-Only Copy — Native and Private

**Native on Apple platforms. Local by design.**

Airframe is built natively in Swift. The macOS version comes first; iPhone and iPad will follow after the interface has been properly adapted for smaller displays and touch interaction. Blackbox logs and Airframe documents are processed locally and are not uploaded to the developer. There are no analytics, ads, or tracking services in the app.

## Website-Only Copy — Spectrum Filter Guides

**See the noise and the filters in the same context.**

Spectrum Filter Guides relate measured gyro data to the aircraft and its Betaflight configuration. Craft-motion, prop-wash and control, and expected motor-noise ranges appear alongside P90 noise references, configured low-pass filters, and RPM-notch harmonics. This helps show where noise occurs and whether the active filters target the relevant frequencies.
