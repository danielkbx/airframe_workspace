# Airframe UI Guide

- Status: normative
- Last reviewed: 2026-08-02
- Scope: shared interaction and layout conventions for Airframe's native SwiftUI interface

This guide records reusable UI contracts. New UI and reviews must follow it together with `PRINCIPLES.md`.

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
