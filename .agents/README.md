# Agent Entry Point

Airframe is a native Swift Betaflight Blackbox log analyzer. This file is only the workspace map and reading order; project decisions live in `MEMORY.md`.

The workspace root is now a private wrapper Git repository:

- Root repo: `git@github.com:danielkbx/airframe_workspace.git`
- Purpose: private planning, `.agents/`, workflow scripts, reference submodule pointers, and private assets.
- Root commits may be short, frequent, and attribution-free.
- Root branch: `master`, tracking `origin/master`.

The upstream reference project is cloned at:

- `blackbox-log-viewer/`
- Upstream: https://github.com/betaflight/blackbox-log-viewer
- Local observed commit: `a039b74492cdbaca6f94852a7958df1c2dc064b1`
- Observed version: `2026.6.0`
- Workspace role: read-only reference submodule. Pull only; never commit or push from this workspace.

The Betaflight firmware reference is cloned at:

- `betaflight/`
- Upstream: https://github.com/betaflight/betaflight
- Local observed commit: `6ecfb45f938e4996fbb568b21eafa7057446a906`
- Workspace role: read-only reference submodule. Pull only; never commit or push from this workspace.

The PIDtoolbox reference (MATLAB source of the free PIDtoolbox, algorithmic ancestor of PIDtoolbox Pro) is cloned at:

- `PIDtoolbox/`
- Upstream: https://github.com/skoch1s/PIDtoolbox (mirror; original bw1129 repo is no longer public)
- Local observed commit: `1e12abb23188183f0f21998a6a89af3719ded22a` (v0.23-3-g1e12abb)
- Workspace role: read-only reference submodule. Pull only; never commit or push from this workspace.
- Purpose: reference for step-response, spectrogram, throttle-spectrum, motor-noise, notch-Q, eRPM, and xcorr-lag calculations. The Pro version's `.m` files are MATLAB Compiler encrypted (V2MCC) and not readable; the free version shares the algorithms.

The Airframe project repository is:

- Local path: `Airframe/`
- GitHub: https://github.com/danielkbx/airframe
- Remote: `origin` -> `git@github.com:danielkbx/airframe.git`
- Workspace role: public project submodule. Commit only with explicit user approval.

Do not modify the upstream clones unless the user explicitly asks for changes there. Planning and agent context should live in `.agents/`.

## Context Durability Rule

Agents must update `.agents/` proactively whenever stable project information changes or emerges. This includes decisions, goals, constraints, rules, known facts, risks, research findings, and agreed next steps. The conversation will often reach context-window limits, so important context must be preserved in files, not only in chat.

Agents must also update `TOOLING.md` as a self-learning knowledge base. If a tool workflow works especially well, is faster than an alternative, or had to be corrected after a failed or unreliable attempt, write down the lesson.

## Recommended First Read

1. `MEMORY.md`: durable decisions and constraints.
2. `PRINCIPLES.md`: working and review rules.
3. `ARCHITECTURE.md`: current technical shape.
4. `TASKS.md`: active work and unresolved decisions.
5. `PLAN.md`: current approved execution plan.
6. `RESEARCH.md`: external facts and source findings.
7. `TOOLING.md`: repeatable workflows and corrections.
8. `BACKLOG.md`: unapproved future ideas.
