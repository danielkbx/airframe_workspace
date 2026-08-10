# Airframe UI Guide

- Status: normative
- Last reviewed: 2026-08-06
- Scope: shared interaction and layout conventions for Airframe's native SwiftUI interface

This guide records reusable UI contracts. New UI and reviews must follow it together with `PRINCIPLES.md`.

## Existing Airframe UI Is the Design System

Before implementing a new surface, inspect the live production views and choose the closest existing Airframe reference.

### Required Reference Pass

- Identify at least one structurally similar production view before writing layout code. Prefer two when the surface must work on both macOS and iOS.
- State which view is the reference and reuse its hierarchy, spacing, typography, control styles, background treatment, sizing, and action placement unless the new workflow requires a deliberate difference.
- Search by interaction and presentation role, not only by feature name. For example, a compact settings modal should start from `AircraftSettingsView`; it should not start from a generic `Form` merely because it edits settings.
- Existing app-specific composition takes precedence over a plausible generic SwiftUI composition. Native controls remain preferred inside that composition.
- Do not invent a new visual language for an isolated feature. If no suitable reference exists, surface that as a design decision before implementation.

### Meaning Before Container

- Do not translate product nouns directly into SwiftUI container types. A requested “list of choices” may describe the available values, not a permanently visible `List`.
- Resolve the interaction semantics first: how many values exist, whether one or many can be selected, how often the control is used, and whether the choices should remain visible.
- When the user specifies a control type such as dropdown, menu, segmented control, or table, preserve that control type unless a platform limitation makes it impossible.
- If the wording permits materially different interaction models, ask before choosing one. Do not silently turn a compact choice into a visible list of rows.

## Compact Settings Modals

Use this contract for small create/edit/save workflows such as Aircraft Settings and preset saving.

### Composition

- Use a content-sized `VStack(spacing: 0)` with three deliberate regions: explanatory header, compact settings content, and a footer separated by a divider.
- The header uses the established Airframe pattern: accent symbol, clear title, and one short secondary explanation. Do not repeat the title in navigation chrome and again inside the content.
- Put related controls in the established secondary-background card with consistent padding and corner radius.
- Place Cancel and the primary action in the footer. Use `.borderedProminent` only for the primary action and disable it until the input is valid.
- Prefer intrinsic/content-driven height. Do not add a large arbitrary minimum height that creates empty space.
- Use the width and padding of the closest existing modal. Adapt the row layout for compact width without changing the interaction model.

### Control Semantics

- Use a native menu-style `Picker` for one-of-many compact choices. Let the picker own selection indication; do not rebuild it as custom rows with manual checkmarks.
- Use a `TextField` only while text is relevant to the selected operation. Hide irrelevant inputs instead of leaving disabled or unexplained rows.
- Hide a choice control entirely when there is no meaningful choice. Example: preset saving omits `Save As` when no user preset exists and shows only the new-preset name field.
- Never offer immutable or invalid targets merely to disable them. Example: Default is absent from preset overwrite choices.
- Show each field label once. Avoid stacking a section title, row label, and placeholder that all repeat the same concept.
- Preserve keyboard focus and Return-key behavior for the active text field, but do not create duplicate hidden focusable controls through adaptive layout containers.

### Density and Hierarchy

- A small workflow must remain visually small. The number of visible controls should determine the modal's height.
- Use spacing to express groups, not to fill a window.
- Keep accent color limited to the header symbol, focused control, and primary action.
- Avoid a bare `NavigationStack + Form` as the default modal template. Use it when the content is genuinely form-like, scrollable, or already follows an established Airframe form surface.

## Prominent Buttons

- Use a prominent button for the single primary action in a dialog, assistant step, card, or compact workflow. Secondary, cancel, and dismissal actions retain their established native/plain styles.
- Apply the shared `airframeProminentButtonStyle()` modifier instead of calling `.buttonStyle(.borderedProminent)` directly. Use it in production views and previews so every prominent button receives the same platform treatment.
- On iOS/iPadOS, the button background uses Airframe's semantic accent color. Primary label and icon content use `primaryOnAccent`; subordinate content placed on the same accent surface uses `secondaryOnAccent`.
- On iOS/iPadOS, prominent button labels use `.subheadline.weight(.semibold)`. Do not override the font, weight, foreground color, opacity, or disabled-state treatment at individual call sites.
- On macOS, the shared modifier preserves the native `.borderedProminent` font and foreground treatment.

## Accent Background Contrast

- On iOS/iPadOS, every Airframe-accent background must use the semantic on-accent foreground colors: `primaryOnAccent` for primary labels and icons, and `secondaryOnAccent` for subordinate content. Do not rely on the system's default accent-foreground inference because Airframe's iOS accent requires a white foreground.
- This applies to prominent controls, tinted swipe actions, badges, chips, selections, and any future custom surface that paints the accent behind content. Keep macOS platform treatment unchanged unless its established component explicitly uses the same semantic colors.

## Visual Acceptance Gate

Build success is not visual verification.

- Before declaring native UI complete, inspect the rendered surface in its real presentation context on every materially different target platform.
- Exercise representative states, not only the easiest preview: empty and populated collections, conditional fields shown and hidden, valid and invalid input, and long localized or user-provided names where relevant.
- Compare the result directly with the chosen Airframe reference for hierarchy, density, alignment, sizing, and action placement.
- A useful debug preview should make those states reproducible. Add multiple previews when one state cannot demonstrate the contract.
- If the environment prevents visual inspection, say so explicitly. Report build/type-check success separately and do not characterize the UI as finished or polished until a screenshot or user check confirms it.
- Treat user screenshots as acceptance evidence. If a screenshot exposes a structural mismatch, revisit the reference and interaction model rather than applying cosmetic spacing patches.

## In-App Application Icons

- On iOS/iPadOS, loading an App Icon asset as a `UIImage` exposes its rectangular image pixels; SpringBoard's rounded icon mask is not inherited by an in-app SwiftUI `Image`. The shared icon view must apply its own continuous rounded-rectangle clip matching the established macOS artwork.
- Keep the mask and any icon-relative overlay placement in the reusable icon view so Home, About, and future in-app presentations remain consistent. Position a badge relative to the visible icon edge; do not rely on transparent padding that exists only in another platform's asset.
- Do not apply the iOS/iPadOS mask to the macOS branch. Preserve the established `NSApplication.applicationIconImage` presentation unless macOS is explicitly being changed.

## All-Or-Nothing Adaptive Groups

- When a small fixed group must appear either entirely in one row or entirely in one column, keep exactly those two complete arrangements. Do not use an adaptive grid that can create an unintended partial row such as `2 + 1`.
- `ViewThatFits` evaluates candidate ideal sizes, which can reject a horizontal group of flexible children even when they can compress into the available row. When the choice must follow an exact content-width threshold, use a small custom `Layout` that reads `ProposedViewSize.width`, distributes the complete row explicitly, and otherwise places the complete column.
- Keep the fallback candidate complete and ordered identically. Validate both sides of the threshold in narrow and wide iPad windows; size class alone is not a sufficient proxy for available content width.

## Overview Card Grid

- Overview cards use one adaptive grid definition with a 280-point minimum and 520-point maximum card width across iOS, iPadOS, and macOS.
- Keep the minimum stable unless compact card readability is deliberately redesigned. The larger maximum lets existing columns absorb intermediate-width remainder instead of leaving a narrow unused trailing strip.

## Management Modals

- On iOS/iPadOS, prefer a simple native list with per-row swipe actions when every operation naturally applies to one item. Do not expose selection checkboxes, Select All, batch-action footers, or redundant visible row-action icons without an approved workflow. Preset management exposes Edit, Share, and Delete only as trailing swipe actions.
- On macOS, use a persistent list when the collection itself is the main content and the user can select several items for batch actions. This is distinct from compact one-of-many configuration, which remains a menu-style picker.
- Make every item row full-width and interactive with a leading native square/checkmark symbol, stable model identity, and explicit selected/not-selected accessibility value. When the row also supports Finder-style inline rename, keep checkbox selection and the full-width name action separate so the editable text field is never nested inside a button.
- When a batch list benefits from selecting all items, place a visually unlabeled checkbox as the first row; the standard position and tri-state mark communicate the action without redundant visible copy. Retain a localized `Select All` accessibility label. Use an indeterminate minus-square for a partial selection; clicking partial selects every current item, while clicking a complete selection clears it.
- Keep batch selection transient. Reconcile it against observable collection changes so deleted or remotely removed identifiers cannot remain actionable; newly arriving items remain unselected.
- On macOS, put destructive and export actions together in the established bottom action area, disable both for an empty selection, and keep the non-destructive dismissal available in empty states.
- Immutable built-in records do not appear in a management list when none of its actions can apply to them.

## Finder-Style Inline Renaming

- Start rename by double-clicking the visible name, replacing only that label with a focused native text field in the same row.
- Return and focus loss commit; Escape restores the existing name. Keep stable model identity while the name changes so list diffing can move the renamed row safely.
- Keep every Airframe-owned key equivalent out of every native text-input session, not only inline rename. Register app shortcuts through the shared `airframeKeyboardShortcut` modifier; it removes the key equivalent while AppKit is editing a text field without disabling the underlying button or menu action. Do not add a raw `.keyboardShortcut`, and gate custom `.onKeyPress` handlers through `TextInputShortcutGate` when they could receive text-input keys.
- Normalize and validate the name in the repository, preserve the record ID and content, and persist the rename atomically. Duplicate or invalid names produce a compact native error.
- Keep the interaction accessible through a named `Rename` accessibility action; do not make pointer double-click the only available semantic action.

## Native Decision and Result Alerts

- Use the platform alert directly for a short decision or acknowledgement; do not wrap simple choices in an Airframe-styled modal, header, card, or custom footer.
- Keep the title short and semantic. Add one concise informative sentence when it clarifies the decision or result; omit secondary text only when it would repeat the title.
- For a conflict, present only the actions that are valid for that exact item. Mark destructive replacement as destructive, use the non-destructive preservation choice as the normal action, and use the skip/cancel choice as the cancel role.
- Resolve repeated conflicts one at a time. Do not show a custom conflict list merely to batch a small sequence of independent native decisions.
- Do not present a success alert for a zero-result operation. Errors and genuine nonzero results remain explicit.

## Collapsible Sidebar Sections

A collapsible sidebar or inspector section has two presentation states, and both must be designed deliberately.

### Required Product Question

Before implementing a new collapsible section, explicitly ask the user:

> What information or control should remain visible while this section is collapsed?

Do not infer the collapsed summary from the expanded content unless the user has already specified it. This question is required because the correct summary is a product decision, not merely a layout detail.

### Contract

- The section header is a full-width plain button with its title, trailing `chevron.right`, and a short rotation animation between 0° and 90°.
- The collapsed state must contain one meaningful summary or control chosen by the user.
- Never leave the `Form` section truly empty. On macOS, an empty SwiftUI `Section` can incorrectly dim the following section header and its controls.
- Do not use an invisible placeholder as the final design. Use the space to preserve useful context or a frequently needed control.
- The collapsed summary must not be duplicated when expanded unless the user explicitly wants it in both states. Prefer one shared row followed by conditional details, or provide state-specific placements for the same control.
- Collapsing changes presentation only. It must not reset selections, calculated data, or persisted configuration.
- Clear transient hover or focus highlights that belong to hidden content when collapsing.
- Add an accessibility identifier and expose the expanded/collapsed state.

### Current Examples

- Spectrum Guides: the selected profile picker remains visible while collapsed; expanded state adds guide ranges, motor-noise ranges, and P90 measurements.
- Graph Craft: the resolved/current craft layout and layout menu remain visible while collapsed; expanded state presents the craft canvas with the layout menu in the canvas.

## Leading Color Dots in Multi-Line Cells

- A leading color dot belongs to the title row and is vertically centered on the title, not across the full cell.
- Secondary detail text sits on its own row with a leading inset matching the title text.
- Spectrum Guide and selection dots use a 10-point diameter.
