# Airframe Knowledge Base

- Status: active
- Last reviewed: 2026-08-05
- Scope: durable external research, reproducible local observations, evidence, uncertainty, and product interpretation
- Normative decisions: `.agents/MEMORY.md`
- Related implementation: `.agents/ARCHITECTURE.md`, `.agents/PLAN.md`, and `.agents/TASKS.md`

The knowledge base records what Airframe knows and why. It is not the normative product specification: accepted decisions belong in `../MEMORY.md`, implemented structure in `../ARCHITECTURE.md`, current execution in `../PLAN.md`, unapproved ideas in `../BACKLOG.md`, and repeatable tool workflows in `../TOOLING.md`.

## Evidence Grades

| Grade | Meaning |
|---|---|
| `A` | Primary evidence: firmware source, an official standard or platform API, Airframe source behavior, or a reproducible local test |
| `B` | Official project documentation or directly inspected upstream implementation |
| `C` | Credible secondary source that is technically plausible and at least partly cross-checked |
| `D` | Airframe hypothesis, proposed heuristic, or observation not independently validated |

Claim status is one of `verified`, `partially verified`, `heuristic`, `conflicting`, `obsolete`, or `open`. A source statement and an Airframe inference must be written separately. Versions and access dates are required where they affect meaning.

## Source Priority

1. Reproducible local tests and the exact source revision that produced behavior.
2. Current firmware/platform source and official specifications.
3. Official project documentation for the relevant release.
4. Inspected reference-tool behavior.
5. Credible secondary explanations.
6. Airframe hypotheses, which must remain Grade `D` until validated.

## Topic Index

| Topic | Purpose | Last reviewed |
|---|---|---|
| [PID Tuning Principles](PID_TUNING_PRINCIPLES.md) | PID-F signal flow, response interpretation, gain relationships, version caveats, and Airframe analysis relevance | 2026-08-05 |
| [Spectrum Tuning Guides](SPECTRUM_TUNING_GUIDES.md) | Filter-delay and spectrum evidence, uncertainties, proposed setup profiles, and validation requirements | 2026-08-05 |
| [Blackbox Format and Compatibility](BLACKBOX_FORMAT_AND_COMPATIBILITY.md) | Frame format, writer/viewer compatibility, headers, versions, and parser behavior | 2026-08-05 |
| [Upstream Analysis Tools](UPSTREAM_ANALYSIS_TOOLS.md) | Blackbox Explorer, PIDtoolbox, related parsers, graph/spectrum algorithms | 2026-08-05 |
| [Flight Controller Connectivity](FLIGHT_CONTROLLER_CONNECTIVITY.md) | MSP, serial, BLE, USB/iPadOS, FlashFS, and hardware validation | 2026-08-01 |
| [Apple Platforms and CI](APPLE_PLATFORMS_AND_CI.md) | Apple framework feasibility and Xcode Cloud entitlement behavior | 2026-08-01 |
| [Map and Graph Research](MAP_AND_GRAPH_RESEARCH.md) | Native flight-map behavior and limitations, route semantics, and graph-layout findings | 2026-08-05 |
| [Licensing](LICENSING.md) | Upstream licensing facts and Airframe implications | 2026-08-01 |

The specialized SpeedyBee reverse-engineering lab notebook remains at `../SPEEDYBEE_REVERSE_ENGINEERING.md`; connectivity research links to it instead of duplicating it.

## Maintenance Rules

- Add unsettled observations to `../RESEARCH.md#research-inbox` first.
- Move stable research into the appropriate topic in the same work round.
- Give every consequential number a source or mark it Grade `D`.
- Do not silently delete contradictory or obsolete evidence that still affects current interpretation; retain it with status and context. Superseded document snapshots remain recoverable through Git and do not need a second in-tree archive.
- Keep one detailed home for each fact and link from other project files.
- Review web sources when their version or current behavior matters.
