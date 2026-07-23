# Project Memory

This file stores durable decisions and constraints. It intentionally omits implementation diaries, commit lists, and test transcripts.

## Product

- Name: Airframe.
- Subtitle: A Blackbox Log Analyzer.
- Native Swift Universal app for iOS and macOS.
- Swift-native parser and model; no WebView wrapper.
- App Store distribution is optional.
- Project language is English for code, documentation, comments, commits, and artifacts.
- Build an independent implementation. Reference upstream behavior and formats, but do not translate source structure or implementation text.
- GPL-3.0 is acceptable if required, but the final license is not chosen.

## Repository Boundaries

- Workspace root: private wrapper repository `danielkbx/airframe_workspace`, branch `master`.
- `Airframe/`: public project submodule `danielkbx/airframe`; commit only with explicit user approval.
- `blackbox-log-viewer/`, `betaflight/`, and `PIDtoolbox/`: read-only reference submodules; never commit or push from this workspace.
- Durable private context lives in `.agents/`.
- Never put AI or automation attribution in `Airframe/`, public documentation, commits, PR titles, or PR descriptions.

## Development Rules

- Planning only unless the user requests implementation.
- No external dependencies without explicit approval. `swift-argument-parser` is already approved for `AirframeCLI`.
- Use Swift 5.9 language mode and modern Swift idioms.
- Prefer async/await and structured concurrency.
- Prefer Swift Testing for packages; XCTest is allowed for app tests, UI automation, and Xcode-specific facilities.
- Use Semantic Versioning. Every package and Xcode target shares one version; Xcode targets inherit `MARKETING_VERSION` from `Base.xcconfig`.
- Use typed, domain-specific errors and `throws` rather than Swift `Result` return values.
- Keep large types in separate files; compact local subordinate types may remain with their owner.
- One-line calls and declarations are preferred when they fit within 150 characters.
- Project file headers use `SPDX-FileCopyrightText: 2026 mail@danielkbx.com`. Do not add a license identifier before the license is chosen.

## Safety And Performance

- Treat every input byte, header, frame definition, event payload, and caller option as hostile.
- Validate bounds and configured budgets before reads, allocation, iteration, or filesystem work.
- Malformed input must produce typed errors, retained issues, or compatibility blocking; never crashes, overflow traps, unbounded loops, or unbounded allocations.
- Keep parser primitives allocation-conscious and suitable for later streaming.
- Whole-flight acquisition should reuse the one-pass scan overview. Full-resolution work should use indexed range queries.
- App-side data processing must run through the per-document `ProcessingActivityCounter`; domain packages remain unaware of UI activity tracking.

## Package And App Boundaries

- Swift packages live under `Airframe/Packages/`.
- Core packages:
  - `BlackboxCore`: parser primitives only.
  - `BlackboxReader`: file/log structure, decoding, recovery, indexing, range queries, and raw series.
  - `BlackboxAnalysis`: derived analysis and app-facing analysis workspaces.
  - `AirframeCaptions`: all user-facing localized strings.
  - `AirframeUnits`: focused locale-aware unit formatting.
  - `AirframeUI`: reusable data-driven UI, charts, and display models.
  - `AirframeCLI`: CLI kit plus thin `airframe` executable.
  - `Logging`: local dependency-free logging infrastructure.
- App-specific navigation, documents, window lifecycle, menus, and composed screens remain in the app target.
- Domain packages must not depend on `AirframeCaptions`; consumers combine semantic IDs with captions.

## User-Facing Text

- Every user-facing label, title, caption, event name, issue message, placeholder, menu item, and accessibility string is owned by `AirframeCaptions` and backed by `.xcstrings`.
- Raw log values, filenames, numeric values, debug-only test names, internal IDs, and machine-readable JSON keys are exceptions.
- User-facing numeric output uses focused locale-aware formatters; units belong in headers, not every numeric cell.
- Public comments explain the format or local design directly and do not cite upstream implementation choices.

## Documents

- The app registers raw `.bbl` and `.bfl` files plus Airframe package documents. `.txt` and `.log` are not system-wide document types.
- Raw logs are read-only and never modified.
- `AirframeWorkspaceDocument` is the shared model for raw logs and `.airframe` packages.
- Package format version 1 contains `metadata.json` and byte-identical source payloads stored under SHA-256-derived paths.
- Package metadata uses one ordered `logs` array. All embedded sources are equal; there is no persistent main/reference distinction.
- Package validation requires at least one source, unique full hashes and paths, safe relative paths, and matching byte counts and SHA-256 hashes.
- Package source order is insertion order and drives global `Log N` numbering. Sources append; reorder UI does not exist.
- Packages have no fixed source limit. Raw windows may hold one main log plus at most eight temporary references.
- Package state is authoritative in `metadata.json`. Raw-log state remains in the external document-state repository and seeds package state once during conversion.
- Package mutations are coalesced and silently persisted. Closing or replacing a workspace flushes pending changes; failed writes remain pending for retry.
- Airframe documents have no persistent document UUID. Runtime windows use ephemeral identity; source/cache identity uses full SHA-256.
- Bookmarks are deliberately absent from format version 1 until behavior and types are designed.
- macOS native Save, Save As, and Revert remain disabled. Duplicate is a coordinated byte-preserving filesystem copy; Rename and Move remain available for packages.

## Document Entry And Presentation

- iOS uses one `HomeView` workspace and `AirframeUIDocument`; macOS uses `AirframeNSDocument` windows plus one non-document start window.
- The shared start view offers Open Log, open a folder of up to eight raw logs, and a visible unavailable flight-controller import action.
- Raw-log opening policy is iCloud-synced and offers `Ask` or `Always Open Read-Only`.
- Conversion language says `Airframe document`, not `editable document`.
- Package sidebars flatten all source segments into one `Logs` section. Raw sidebars preserve file/log/reference hierarchy.
- Package source names may be customized per segment without changing bytes, hashes, parser titles, or original filenames.
- Effective package names are used consistently in navigation, Graph/Spectrum, and Step Response.
- Source removal is context-menu-only. Raw removal detaches without deleting the original file; package deletion removes embedded bytes and all contained logs from the document.

## UI Architecture

- `DocumentHomeView` owns document composition and the stable `NavigationSplitView`.
- The sidebar is contextual navigation; the selected log's data belongs in the detail area.
- Current views are Overview, Table, Graph, Spectrum, and Step Response.
- Table and Graph share one timeline position/range and one playback transport. Future video must synchronize to this master transport.
- Table, Graph, Spectrum, and Step Response use reusable data-processing stages and document-scoped caches.
- Per-window transient UI state lives in `DocumentStateStore`. Package-persistent state lives in metadata.
- SwiftUI view files in the app target and `AirframeUI` require at least one realistic `#if DEBUG` preview using production model types.
- Every selectable Reader or Analysis series needs semantic classification, caption, unit, conversion, precision, raw fallback, and focused tests before UI exposure.

## Git And GitHub

- Root workspace commits may be short, frequent, and attribution-free.
- Never commit in `Airframe/` without explicit user approval.
- Never commit or push reference submodules.
- Use `gh` with account `danielkbx`; verify the active account before every push or PR action.
- Do not use Conventional Commit prefixes.
