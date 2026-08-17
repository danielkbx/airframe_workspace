# Marketing Information

This file is the durable source for Airframe's public identity, messaging, contact channels, and release communication.

## Product Identity

- Product name: `Airframe`.
- Product subtitle: `A Blackbox Log Analyzer`.
- Brand slogan: `Every flight tells a story.`.
- The subtitle is the factual product description; the slogan is the emotional brand line.
- Product language is English.

Recommended presentation:

```text
Airframe
A Blackbox Log Analyzer
Every flight tells a story.
```

## Current Public Identity

- Airframe will later be presented under the future company name.
- Until then, the public developer identity is `danielkbx`.
- Preferred attribution: `Built by danielkbx`.
- Contact email: `mail@danielkbx.com`.

## Community

- Discord invite: `https://discord.gg/rZkmzRE93`.
- The Discord server is intended for both prerelease and released versions; do not describe it as beta-only.
- Discord description: `The community for Airframe—share feedback, report bugs, discuss Betaflight Blackbox analysis, and help shape the app.`

## Product Showcase

- Reusable Discord and future website source material lives in `marketing/product-showcase/`.
- Product-showcase screenshots live in platform folders below `marketing/product-showcase/Screenshots/`. Matching features reuse the same numbered semantic filename. The current companion mobile set contains 13-inch iPad simulator captures, not iPhone captures.
- The first showcase is a sequence of independent text-and-image posts because Discord has no dependable editorial layout.
- The opening founder story starts with tuning from a camping chair, frustration with slow and old-fashioned tools, Daniel's macOS/iOS development background, and the decision to build a modern, fast analyzer with direct flight-controller import.
- The first Discord series focuses on Overview, Graph and playback, Spectrum, Step Response, Map, and Flight Controller Import. Airframe document organization and native/local privacy remain website material rather than standalone Discord posts.
- Public prerelease messaging must state that Airframe is still in active development and does not yet contain every feature planned for version 1.0.
- Acknowledge that Airframe may not yet cover every analysis or view found in other tools. Explain that the current features are the ones Daniel genuinely needed for his own tuning and that have already helped in practice.
- Invite users to suggest missing analyses, views, and workflows; feedback from real flights should help shape development priorities.
- Discord showcase messaging should promise channel updates when Airframe receives major changes or noteworthy new features, without implying a fixed update schedule.
- Flight Controller Import messaging should explicitly name USB cable, Bluetooth, and SpeedyBee Adapter 3 support. Bluetooth and Adapter 3 enable direct flight-controller import on iOS devices.
- Spectrum Filter Guides are a primary website feature and the headline for tester build 43. Describe them as placing aircraft-specific motion, prop-wash/control, and motor-noise regions, P90 references, and recorded Betaflight filter curves in the context of the measured spectrum so pilots can judge whether filters target the relevant noise.
- The Build 47 Discord update focuses on CHIRP analysis. Its paired screenshots show the response/Tune Score result and the supporting Spectrogram evidence. Messaging must keep the underlying measurements visible and describe Tune Score as an assessment of the recorded flight rather than a tuning recommendation.
- The macOS version comes first. Public messaging must say that iPhone and iPad will follow later because smaller displays and touch interaction still require dedicated adaptation.
- Map must be described as beta. Show its useful current state honestly, use a static capture, and say that presentation and playback are still being refined.
- Do not advertise backlog, hidden, incomplete, or known-problem behavior as finished.
- Public showcase copy is English and should lead with user outcomes rather than internal implementation.
- Showcase language should be neutral and explanatory rather than promotional. Describe what each feature is for and which question it helps answer; avoid imperative, user-directed sales language.

## Website

- The static website source lives in `marketing/website/`, outside the public Airframe submodule; `dist/` is a replaceable build product and is not tracked.
- The landing page uses the app's near-black background, `#D3FC03` accent, restrained signal colors, a telemetry-line background, generous whitespace, and large natural-ratio screenshots. It must not drift into a repetitive card wall or generic template styling.
- The landing-page showcase begins with Overview, which combines recorded evidence, user-owned aircraft context, any available imported flight-controller configuration, and supported checks by topic. Its detailed Inside Airframe guide uses a general setup health-check metaphor, while remaining explicit that missing evidence is not a healthy verdict and that the result is not a physical inspection, universal diagnosis, or tuning recommendation.
- `Inside Airframe` begins with `Start with Airframe`: the Airframe document guide introduces the multi-log analysis workspace and its non-lock-in export story, followed by the existing flight-controller import guide and the setup health check. Rendered content links `Airframe document`, `Airframe documents`, and the standalone `.airframe` extension to `/inside-airframe/airframe-document/`, except inside the target guide itself.
- `Inside Airframe` is the public name for the technical guide. It starts with a pilot's problem or question and then routes to the relevant app views; it must never become a view-by-view feature manual.
- The `Noise and control` guide sequence is evidence-first: identify noise behaviour, judge the achieved filter outcome, interpret ordinary-flight PID-F response, and only then read a supported CHIRP Tune Score. CHIRP response data is considered only when the spectrogram shows a distinct, continuous sweep following the expected frequency curve from start to finish on every recorded axis. Public guidance must keep source, attenuation, delay, control response, score, and confidence distinct; it offers no universal thresholds, setting values, one-term diagnoses, or claims for features Airframe does not yet provide.
- English guide content is structured JSON below `marketing/website/content/en/`; layout remains independent. Search is intentionally deferred.
- Screenshot content uses stable logical IDs in one registry. Website masters are copies of approved marketing screenshots, intrinsic dimensions are discovered during the build, and replacing a master must not require a content or layout edit.
- Every visible raw-square logo copy is clipped with the shared 22.5% app-icon shape. Rounded raster derivatives are reserved for favicon/platform metadata uses.
- Screenshots remain normal full-resolution links without JavaScript and upgrade to one accessible native-dialog gallery when JavaScript is available.
- The website makes no third-party requests and uses no analytics, cookies, local storage, embedded social media, or remote fonts.
- The prerelease CTA is Discord. A real domain, domain email, and App Store URL are mandatory publication gates; do not publish placeholder destinations.
- The Mac release comes first. Website prerelease copy may say iPhone and iPad are coming later, but must not imply those platforms are currently available.

## Monetization

- The final monetization model is not decided.
- Airframe will not use subscriptions or recurring charges.
- People who contribute publicly to the FPV community through open-source work, software, videos, guides, documentation, blog posts, or comparable resources are eligible for free lifetime access to every Airframe feature. They contact the developer through the existing feedback channel; eligibility is assessed personally without a published minimum audience, output, platform, or contribution threshold.
- Any future purchase, Pro, licensing, or entitlement system must support this permanent community access policy.
- The likely direction is a one-time purchase that unlocks a Pro-style set of capabilities.
- Possible paid candidates include direct flight-controller communication and advanced analysis features needed by only a relatively small group of users.
- Exact paid scope and pricing remain open and must not be presented as final.

## About Direction

- The shared macOS/iOS About screen uses the Home screen's visual language.
- It shows the app icon, `Airframe`, `Version <version> · Build <build>`, the prominent slogan, a short description, `Built by danielkbx`, feedback, Discord, and privacy.
- `Acknowledgements` opens an in-app detail that thanks and links to the public websites for Betaflight (`https://betaflight.com`), Betaflight Blackbox Log Viewer (`https://blackbox.betaflight.com`), Betaflight Configurator (`https://app.betaflight.com`), and PIDtoolbox (`https://pidtoolbox.com/home`). It also states the permanent free-access policy for people who contribute public work or resources to the FPV community and routes requests through `Send Feedback`.
- The community-access offer appears before the acknowledged project list. macOS also exposes `Acknowledgements` as its own Help-menu command opening the same view in a single reusable window.
- About and standalone macOS Acknowledgements use key-capable borderless windows with clear outer window backgrounds, fully opaque system-window backing behind the rounded clipped SwiftUI content, shadows, and the shared in-content X close control. This preserves transparent rounded corners without allowing the desktop or other windows to show through the content, and no native titlebar remains to reserve or draw a top strip. Both macOS Acknowledgements presentation paths use an exact 420 × 620 pt size; iOS remains adaptive. Acknowledgements places its title and close control in a fixed non-scrolling header followed by a separately clipped ScrollView, so content cannot render behind the header even during macOS overscroll.
- Keep `A Blackbox Log Analyzer` available as the factual subtitle.
- On macOS, `About Airframe` opens one custom About window. On iOS and iPadOS, the settings button opens a menu containing Settings and About Airframe.
- Website and imprint are implemented locally but not yet published; do not show dummy destinations in About before the real domain is live.

## Privacy

- Airframe sends no app, flight, analytics, or usage data to the developer and contains no analytics, advertising, or tracking services.
- Blackbox logs and Airframe documents are processed locally and are not uploaded to the developer.
- User-submitted feedback is processed only to fix bugs or improve Airframe. It is not shared or published without the author's permission.
- These statements are available directly in the app through About → Privacy.

## Feedback

- Primary contact: `mail@danielkbx.com`.
- Discord is the community channel.
- A prepared feedback email may include app version, build, platform, OS, device model, and architecture.
- Never attach or include Blackbox data, filenames, file paths, controller identifiers, or logs automatically.

## What's New

- The `release/0.1.0` highlights cover the native flight map, Spectrum filter insight, automatic log tags and hiding, restored view state and cached analysis, safer Airframe documents, and the more personal About/privacy/community experience.
- Tester build 43 is marked in the public repository by `build/43` at `6e38f52`. Its tester notes cover aircraft settings and center-of-gravity diagnostics, interactive Spectrum tuning guides and stable mode switching, battery cell count with per-cell voltages, and restored per-log In/Out points.
- Tester build 47 is marked by commit `6f8aa06`. It covers CHIRP frequency-response analysis and tune scoring, smoother Graph/Table playback and scrubbing, faster reopen through persistent derived-data caching, improved Craft attitude/loading/CHIRP status, Betaflight 2026.6.1 compatibility, portable presets, broader Bluetooth import, Overview tools, document reliability, UI refinements, and Acknowledgements/community access.
- The in-app What's New entry uses numeric catalog ID `3` and covers four concise user-facing themes: CHIRP Analysis, performance, Acknowledgements, and broad UI improvements. Technical test instructions remain exclusive to TestFlight notes.
- The next in-app What's New entry uses numeric catalog ID `4` and covers four concise user-facing themes: portable analysis presets, broader Bluetooth flight-controller import, new Overview tools, and performance/document reliability. Technical test instructions remain exclusive to TestFlight notes.
- The next tester update changes only the TestFlight notes. The in-app What's New catalog remains unchanged at numeric catalog ID `4`.
- The next in-app What's New entry uses numeric catalog ID `5` and covers the expanded Flight Map, GPS route export, original Blackbox field names in editors, and distinct Finder icons for Airframe documents and presets.
- The next in-app What's New entry uses numeric catalog ID `6` and covers Spotlight flight search, start-location access to Flight Map, clearer Overview checks, and sharper Spectrum guidance.
- TestFlight notes describe only what is new. They use concise declarative release-note language, never testing instructions, requests, or `What to Test` framing.
- What's New shows the app version below its title. Beta builds also show the build number; production builds do not.
- TestFlight notes for build 47:

  ```text
  What to Test

  • Open a CHIRP log and check automatic detection, Frequency Response, spectrogram guides, Tune Score, and recorded PID settings.
  • Scrub and play large logs in Graph and Table. Reopen a document to verify faster loading from the on-device cache; cache controls are available in Settings.
  • Check Craft attitude, loading feedback, motor values, flight modes, and the active CHIRP axis while scrubbing.
  • Review the reorganized Overview, updated Settings, inspector scrolling and hover behavior, and keyboard navigation between logs and views.
  • If available, open a Betaflight 2026.6.1 log and verify its headers and analysis.

  Please report regressions, confusing results, and logs that do not behave as expected through Send Feedback or Discord.
  ```
- TestFlight notes for the next tester build after build 47:

  ```text
  • Improved iPad navigation, touch gestures, control sizing, and access to Home and Logs.
  • Step Response now includes T50 and rise time, highlights the best axes, and supports horizontal zoom, panning, and a time crosshair.
  • Spectrum range measurement is available again, hidden legends stay hidden, and zooming, panning, and window resizing are smoother.
  • Flight Controller Import can create privacy-safe diagnostic emails with technical details for troubleshooting.
  ```
- Git commits are editorial source material, never direct user-facing release notes.
- Public Airframe release tags use `release/<semver>`.
- Tester build tags use `build/<build-number>`.
- Only explicitly marked catalog releases trigger automatic presentation.
- What's New uses monotonically increasing numeric catalog IDs independent of app versions and builds. The local and iCloud marker is stored under `lastSeenWhatsNewsCatalogId`; users receive every catalog entry with a higher ID, then the highest presented ID is retained.
- A true first launch shows no What's New screen.
- A true first-time user also sees no manual What's New action in About or Help. Existing users retain it, and it becomes permanently available after the first real update through the synchronized `hasWhatsNewHistory` marker.
- Changes across skipped releases are combined by topic rather than presented as consecutive version pages.
- What's New remains manually accessible through About and shows only the newest catalog entry so the manual view stays concise.
- macOS also exposes `What's New in Airframe` in the Help menu for repeat viewing and testing; manual presentation never changes the synchronized seen marker.
- A release counts as seen when its automatic presentation is shown.
- The seen release is mirrored locally and through iCloud key-value storage so it normally appears once per iCloud user, not once per device.
- The synchronized value contains only the highest presented numeric catalog ID.
- Automatic presentation may wait up to two seconds for a newer cloud value; the app itself remains usable.
- Offline devices can rarely show the same release more than once. No server is introduced to eliminate that edge case.

## Changelog Commit Input

- Before every commit in the public `Airframe/` repository, ask the user whether the change is changelog-relevant.
- Relevant commits use an English, user-oriented Git trailer after a blank line:

  ```text
  Changelog: Navigate large flight logs more smoothly.
  ```

- The trailer is a draft for later editorial review, not an automatically published release note.
- Private workspace commits do not require this question or trailer.
