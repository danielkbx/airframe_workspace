# Agent Entry Point

This workspace is for exploring Airframe, a native Swift implementation of a Betaflight Blackbox log analyzer.

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

The Airframe project repository is:

- Local path: `Airframe/`
- GitHub: https://github.com/danielkbx/airframe
- Remote: `origin` -> `git@github.com:danielkbx/airframe.git`
- Workspace role: public project submodule. Commit only with explicit user approval.

Do not modify the upstream clones unless the user explicitly asks for changes there. Planning and agent context should live in `.agents/`.

## Context Durability Rule

Agents must update `.agents/` proactively whenever stable project information changes or emerges. This includes decisions, goals, constraints, rules, known facts, risks, research findings, and agreed next steps. The conversation will often reach context-window limits, so important context must be preserved in files, not only in chat.

Agents must also update `TOOLING.md` as a self-learning knowledge base. If a tool workflow works especially well, is faster than an alternative, or had to be corrected after a failed or unreliable attempt, write down the lesson.

## User Direction

- Project/app name: Airframe.
- Product subtitle: A Blackbox Log Analyzer.
- The future app should preferably be fully native.
- Parser and model should be implemented in Swift, not just wrapped in a WebView.
- Data/model and UI should be separated, likely as Swift Packages.
- GPL-3.0 licensing is acceptable if needed, but not automatically required. If the implementation is independent rather than a translation/port of GPL JS/C/C++ code, choose the project license later.
- Build an independent Swift implementation. Study upstream JS/C/C++ to understand format behavior, inputs, outputs, and edge cases, but do not translate upstream source line by line or preserve its file/function/variable structure.
- Public code comments should explain the format or local implementation decisions directly. Do not justify behavior by referring to what upstream code, Blackbox Explorer, Betaflight, JS, C, or C++ does.
- App Store distribution is optional; sideloading or non-App-Store distribution is acceptable.
- Current phase is planning and discussion. Do not implement the app yet unless the user asks.
- Do not introduce external dependencies without the user's explicit approval.
- Project language is English for all code, variables, documentation, agent files, comments, commit text, and project artifacts, even when the chat conversation is in German.
- Never mention AI, agents, Codex, ChatGPT, or automation attribution in `Airframe/`, official documentation, commit messages, PR titles, or PR descriptions. Anything other people may see must look like normal developer-authored project work.
- Human-visible text should sound like practical developer writing: clear, a bit casual where it fits, and not weirdly polished or generated.
- File headers in this project should use `SPDX-FileCopyrightText: 2026 mail@danielkbx.com`. Do not add an SPDX license identifier until the license is explicitly chosen. This is project-specific and must not be generalized to other workspaces.
- Use `gh` for GitHub interaction with the `danielkbx` account. Only switch the active `gh` account immediately before actual `gh` usage, not preemptively for local-only work. Verify the active account before every push or PR action.
- Use Semantic Versioning. All Swift Packages and every Xcode target must share one version number. Xcode targets should inherit `MARKETING_VERSION` from `Base.xcconfig`, which may be included by other xcconfig files.
- Use Swift 5.9. Build targets may use the latest stable iOS and macOS releases.
- Prefer modern Swift, async/await over completion blocks, and modern Swift Testing.
- Prefer one-line calls and function declarations when they fit within 150 characters.
- Prefer namespacing with nested Swift types, and keep large types in separate files. Compact subordinate types may live near their parent type as extensions.
- Shared subordinate types should get their own files. Prefer `throws` over Swift `Result`, with concrete type-specific `Error` types where useful.
- Use upstream code as a behavioral reference and oracle, not as implementation text. Swift APIs, type names, errors, and data flow should be native to this project.

## Recommended First Read

1. `MEMORY.md` for durable decisions and context.
2. `RESEARCH.md` for what has already been learned from the upstream repo and web sources.
3. `ARCHITECTURE.md` for native Swift architecture options.
4. `TASKS.md` for possible next planning steps.
5. `TOOLING.md` for learned local tool workflows and corrections.
6. `PLAN.md` for the current investigation and implementation plan.
7. `PRINCIPLES.md` for core working principles and compact operational output style.
8. `BACKLOG.md` for parked ideas and future possibilities.
