# Licensing

- Status: open decision
- Last reviewed: 2026-08-01
- Scope: upstream license facts and implications for Airframe
- Normative decisions: final project license not selected
- Related implementation: repository distribution and any future source reuse

## Evidence Matrix

| ID | Claim | Source | Grade | Scope | Airframe impact | Status |
|---|---|---|---|---|---|---|
| LIC-001 | Betaflight Blackbox Explorer is GPL-3.0 licensed. | BLV-LICENSE | A | Current inspected repository | Reuse or translation of protected implementation may impose GPL obligations. | verified |
| LIC-002 | Independent implementation from public format behavior and original Swift design does not automatically adopt the viewer's license. | General project interpretation | D | Airframe design | Maintain independent structure and obtain legal review before final distribution decisions. | partially verified |
| LIC-003 | GPL-3.0 is acceptable to the project and App Store distribution is optional, but Airframe's final license is not chosen. | Project decision | A | Product | Licensing remains open, not blocked. | verified |

Airframe uses upstream projects as behavioral and format references and should avoid translating source structure or implementation text. This file records engineering context, not legal advice.

## Source Register

| Source ID | Title | Author/project | Version/date | URL or local path | Accessed | Notes |
|---|---|---|---|---|---|---|
| BLV-LICENSE | LICENSE | Betaflight Blackbox Explorer | commit `1222587e162fd2c881ee2ea3d74ec91c2397891d` | `blackbox-log-viewer/LICENSE` | 2026-08-05 | GPL-3.0 text unchanged |
