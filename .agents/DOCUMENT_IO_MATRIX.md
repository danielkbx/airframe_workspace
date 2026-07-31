# Document I/O Matrix

This file is the authoritative inventory for user-visible file boundaries. A path is not considered verified merely because codec or model tests pass.

| Journey | Platform owner | Input/output contract | Publication and scope rule | Automated boundary coverage | Manual provider/UI gate |
|---|---|---|---|---|---|
| Open `.airframe` | macOS `AirframeDocumentController` / `AirframeNSDocument`; iOS `AirframeUIDocument` | Regular file, exact `.airframe`, container validated | Document owns access for its lifetime | Codec, native macOS lifecycle, UTI declarations | Finder/Open Recent, iOS Files, iCloud/provider |
| Open `.bbl` / `.bfl` | macOS controller; iOS picker/UIDocument | Read-only regular file, exact supported extension | Scope spans complete byte read | Parser and temporary-file tests | Native picker on both platforms |
| Open folder | `FolderLogImport` | Immediate non-hidden BBL/BFL; first main, rest references | Folder scope spans enumeration and all reads; no child URL retained | Sorting/cap/data tests | Sandboxed picker/provider folder |
| Attach logs | `ReferenceLogStore` | BBL/BFL only | Each URL scoped through complete read; persisted as blobs | Store/import tests | Multi-select and drag/drop provider URLs |
| Raw/folder → Airframe | `DocumentView` | Final regular `.airframe` | Dialog owns extension/exact URL; candidate prebuilt and validated | Conversion, filename and panel tests | Open Folder → Save → reopen |
| FC → new Airframe | completion coordinator | Final regular `.airframe` | Candidate in replacement directory; exact coordinated publish; open before cleanup | Durability/order/overwrite tests | Hardware import to local/iCloud/provider |
| FC append | workspace controller + persistence actor | Append existing container | Durable flush before erase/temp cleanup | Duplicate/config/flush tests | Native append, close, reopen |
| Autosave | persistence actor | Append-only commit | Document-owned URL; no FileWrapper persistence | Retry/coalescing/native macOS tests | iCloud/provider mutation |
| Close/compaction | NSDocument / UIDocument | Flush required; maintenance best effort | Flush failure vetoes close | Store/platform tests | iOS background/termination smoke |
| Duplicate | `AirframeNSDocument` | Regular validated container | Flush; stage/validate; exact atomic replace; then open | Orchestration/overwrite tests | Native dialog/local/iCloud |
| Rename/Move | NSDocument | Same regular container | Platform coordinated; backing follows new URL | Action-policy tests | Rename/move, mutate, reopen |
| Legacy conversion | Explicit temporary converter | Package input, regular output | Preflight first; replacement staging; exact publish | Real/v1/v2/opaque/in-place tests | Actual picker/save panel |
| Export raw log | SwiftUI FileDocument | Exact `.bbl`/`.bfl`, byte-identical | System owns exact destination | Artifact/filename tests | Cancel/overwrite/provider |
| Export/import preset | FileDocument / NSOpenPanel | Exact `.apf`, JSON | Exact picker URL only | Artifact/codec tests | Dialog/provider |
| Raw container export | Package `ContainerExporter` | Directory tree, no overwrite | Replacement staging; exact destination | Package tests | Only when exposed in UI |

## Global invariants

- New `.airframe` documents are regular files. Directory packages are accepted only by the temporary explicit legacy converter.
- A Save dialog owns the final extension. Code never appends an extension and writes to an unauthorized sibling after selection.
- All macOS native Save panels use `AirframeSavePanel`; a source guard prohibits direct construction elsewhere.
- AppKit Save, Save As, Revert, and Versions commands are absent from the File menu; persistence is automatic and explicit.
- Candidate construction and hashing occur away from the Main Actor. Publication is coordinated onto the exact authorized URL.
- Confirmed replacement preserves the previous destination until the candidate is complete and validated.
- Published output opens successfully before source windows close or FC/temp payloads are destroyed.
- Failed durable flush remains retryable and is not reported as a successful close.
- `/tmp` tests do not prove sandbox/provider behavior. Manual gates remain required until exercised on the named provider.
