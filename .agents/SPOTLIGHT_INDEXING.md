# Spotlight Indexing

Concept and implementation of the Spotlight integration for Airframe-supported files (`.bbl`, `.bfl`, `.airframe`). Written 2026-08-17, revised the same day: the earlier in-app `CSSearchableIndex` enrichment was removed by user decision because app-written items outlive deleted/moved files; the import extension is the single Spotlight source. Reusable building blocks for a future QuickLook extension are marked with **[QL-reusable]**.

## Goal

Users search Spotlight for log details (craft name, firmware, board, log start date, flight location, notes, tags) and open results directly in Airframe.

## Architecture

One index path: the file-based import extension **`AirframeSpotlightImporter.appex`** (extension point `com.apple.spotlight.import`). The system invokes `update(_:forFileAt:)` for every on-disk file matching `CSSupportedContentTypes` and grants read access to that file only. Items live and die with the file — no staleness, no dead results, no `CSSearchableIndex` bookkeeping. Results carry the file URL; Launch Services (macOS) and `onContinueUserActivity(CSSearchableItemActionType)` in `HomeView` (iOS) open them.

The extension works from bounded prefixes only — no full scan:

- Header preview (`ReaderHeaderPreviewOptions.spotlight`: 256 KiB initial / 4 MiB max / 32 segments) for craft, firmware, board, start date.
- Bounded first-GPS-fix decode (`DecodedLog.firstGPSFix`, budget 512 KiB / 8192 frames per segment): the absolute GPS home frame arrives within kilobytes of the segment header, so the start coordinate is cheap.
- Time-boxed (2.5 s each) reverse geocoding through the shared `AirframeGeocoding` package turns coordinates into place names; failures or timeouts only drop the names. The extension carries the `com.apple.security.network.client` entitlement for this.

Multi-log documents: every embedded log contributes headers and its own first GPS fix. Distinct coordinates (deduplicated on a ~1 km grid, capped at 3) are all geocoded — the primary one fills the semantic place attributes, every resolved place name becomes a searchable keyword. A single distinct craft names the item; mixed-craft documents keep the document's filename as title and list all crafts in the description.

## Components

- `Packages/BlackboxReader/…/ReaderHeaderPreview.swift`: `.spotlight` options preset and `previewHeaders(data:sourceName:options:)` for already-loaded prefixes. **[QL-reusable]** — the unused `.quickLook` preset (64 KiB / 1 MiB / 1 segment) was built for exactly the QuickLook budget.
- `Packages/BlackboxReader/…/ReaderFirstGPSFix.swift`: `ReaderFirstGPSFix`, `ReaderFirstGPSFixOptions`, `DecodedLog.firstGPSFix(options:)` — streams frames from the segment start and returns the first valid `H` (home) or `G` coordinate within the byte/frame budget, else nil. **[QL-reusable]**
- `Packages/AirframeGeocoding`: the single reverse-geocoding implementation (`ReverseGeocodingClient` protocol, `MapKitReverseGeocodingClient`, `GeocodedPlace`). Used by the app's flight map (`MapKitFlightReverseGeocodingClient` delegates to it) and by the import extension. **[QL-reusable]**
- `Packages/AirframeSpotlight` (UI-free; deps: BlackboxReader, BlackboxCore, AirframeContainer — deliberately network-free): **[QL-reusable]**
  - `LogSearchAttributes` with `craftNames`, `startCoordinates: [LogSearchCoordinate]` (primary first), `city/region/country`, plus `withPlace(...)` (primary place, names into keywords) and `addingKeywords(...)` (secondary place names).
  - `LogSearchAttributesMapper`: `attributes(forLogFileAt:)` (4 MiB prefix read), `attributes(forContainerAt:)` (manifest + metadata blob + 1 MiB log-blob prefixes, fixes collected per log), pure `attributes(headers:filename:notes:tags:originalFilenames:firstFixes:)`; typed `Error` cases `noHeadersFound`, `containerUnreadable`, `logUnreadable`.
  - `ContainerMetadataSummary` / `ContainerManifestSummary`: lenient `Decodable` views, deliberately independent of app-target types so schema drift never breaks indexing. **[QL-reusable]**
- `App/AirframeSpotlightImporter/`: extension sources, `Info.plist`, sandbox + network-client entitlements. Built as an **ExtensionKit extension** (`EXTENSIONKIT_EXTENSION = YES`, `EXAppExtensionAttributes` with `EXExtensionPointIdentifier`/`EXExtensionPrincipalClass`/`CSSupportedContentTypes`, embedded in `Contents/Extensions/` via a copy phase with `dstSubfolderSpec = 16`). Classic `NSExtension`/PlugIns placement registers only the PlugInKit endpoint; the modern CoreSpotlight host connects via `<bundle-id>.apple-extension-service`, which only ExtensionKit extensions expose. **[QL-reusable]** — the target-wiring recipe (xcodeproj script, shared xcconfig chain for `MARKETING_VERSION`, manual Info.plist with full bundle-identity keys because `GENERATE_INFOPLIST_FILE = NO`) transfers directly to a QuickLook target.
- iOS result opening: `HomeView.onContinueUserActivity(CSSearchableItemActionType)` extracts the file URL from `CSSearchableItemActivityIdentifier` and holds the security scope across the async open.

## Attribute mapping

One Spotlight item per file; multi-segment and multi-log documents are summarized:

- `title`: the single distinct craft name if there is exactly one, else the filename stem; `" (N flights)"` appended for multi-segment documents. Mixed-craft documents never present one craft as "the" craft.
- `contentDescription`: craft list (when mixed) · distinct firmwares · distinct boards · segment count · earliest start date.
- `keywords`: deduped union across all segments/logs of craft, firmware type/revision, board, product, device UID; containers add tags and original filenames; every geocoded place name (primary and secondary locations) is appended.
- `contentCreationDate`: earliest parseable `logStartDateTime` (ISO8601, fractional-seconds fallback).
- Notes (containers): `textContent` (full-text tokenized) plus `comment`, read from the on-disk container metadata.
- Location: `latitude`/`longitude` from the primary (first distinct) log-derived GPS fix; `city`, `stateOrProvince`, `country` from its reverse geocode. Spotlight supports only one semantic location per item; secondary locations are searchable via keywords.
- UTIs: imported blackbox types conform to `public.data, public.log`; the exported container type additionally to `public.content`.

## Location and the MapKit terms

Reverse-geocoded place text is otherwise strictly transient (see DOCUMENT_IO_MATRIX invariant). The Spotlight index is the single, deliberate exception, decided by the user on 2026-08-17. With the importer as the only writer, the place names live in the system's file index entry: they are regenerated on every reindex and removed with the file, which keeps the storage transient in substance. Place names are never written to Airframe metadata, container blobs, caches, or exports.

## Verification status (2026-08-17, macOS 27.0 beta / Xcode 27 beta 4)

- Unit tests: BlackboxReader 256 green (incl. first-GPS-fix suite with a synthetic signed-VB home frame), AirframeSpotlight 10 green (mapper, multi-segment, prefix GPS fix, place merging, container round-trip via `ContainerWriter`).
- Builds: macOS and iOS Simulator green, extension embedded in `Contents/Extensions/`.
- Registration: `pluginkit -m -p com.apple.spotlight.import` lists the importer (elected `+`); `mdimport -e` shows it with label and supported types.
- **OS-side blocker on this beta host**: the system's own `mdimport`/`mdbulkimport` cannot register third-party Spotlight import extensions with BackgroundTaskManagement — `backgroundtaskmanagementd` rejects it with "lacks entitlement 'com.apple.private.backgroundtaskmanagement.manage'", after which the extension session setup fails (`…apple-extension-service` lookup, error 3). The extension process itself launches and bootstraps cleanly. `mdimport -t` only exercises legacy importers and never CSImportExtensions.
- `sfltool dumpbtm` additionally shows the Airframe **app** BTM item as `disabled` (stale record pointing at an old DerivedData Debug path), while the `AirframeSpotlightImporter.appex` item (Type: spotlight) is `enabled` but recorded with the old `Contents/PlugIns/` URL. Relaunching the installed app did not refresh either record. Candidate manual fixes: enable Airframe under System Settings > General > Login Items & Extensions, or reset BTM (`sfltool resetbtm`, admin, re-approves everything). Both need the user.
- iOS Simulator does not run the file-indexing pipeline for File Provider storage; importer verification there is limited to registration. Real-device retest recommended.

## Verification commands

```
pluginkit -m -v -p com.apple.spotlight.import
mdimport -e                    # modern importers incl. extension label
mdimport -m -y com.betaflight.blackbox-log -u "file:///path/file.bbl"
mdfind 'kMDItemTitle == "<craft>"' ; mdls <file>
/usr/bin/log show --last 5m --info --predicate 'subsystem == "com.kumkju.airframe" AND category == "spotlight-importer"'
```
