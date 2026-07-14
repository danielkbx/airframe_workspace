# Core Working Principles

These principles apply to all work in this repository and must shape every plan, implementation, review, and status update.

## Non-Negotiable Engineering Goals

Stability, security, and performance are always active goals.

- Stability: prefer deterministic parsing, explicit errors, isolated tests, and no hidden reliance on execution order or mutable global state.
- Security: treat log files as untrusted input; validate bounds before reads, preserve recovery options, and never allow malformed input to trigger unsafe memory or filesystem behavior.
- Performance: keep parser primitives allocation-conscious, single-pass where practical, and suitable for later large-log streaming without forcing whole-file loading.

## 1. Think Before Coding

Do not assume. Surface uncertainty. Name tradeoffs.

- State assumptions explicitly before implementing.
- If multiple interpretations exist, present them instead of picking one silently.
- If something is unclear, stop and name the ambiguity.
- If a simpler approach exists, say so.

## 2. Simplicity First

Use the minimum code that solves the actual task. Nothing speculative.

- Do not add features beyond what was requested.
- Do not introduce abstractions for one-off code.
- Do not add flexibility or configurability that was not asked for.
- Do not build for hypothetical future requirements.
- If the solution feels overcomplicated, simplify it.

## 3. Surgical Changes

Touch only what is needed. Keep scope tight.

- Every changed line should trace directly to the request.
- Do not opportunistically refactor adjacent code, comments, or formatting.
- Match the existing style unless there is a clear project rule requiring otherwise.
- Remove imports, variables, or functions only when your change made them unused.
- If unrelated dead code is noticed, mention it instead of deleting it unprompted.

## SwiftUI Preview Rule

Every SwiftUI view file in the app target and in the `AirframeUI` package must include at least one preview block.

- The preview block must be inside `#if DEBUG`.
- One preview block per file is sufficient, even when the file contains multiple private helper views.
- Previews should show the file's views in useful, realistic context. Wrap views in `NavigationStack`, `NavigationSplitView`, container views, or other local context when that is needed to represent the real UI.
- Previews must use the real production display/model/state types used by the UI, not separate preview DTOs.
- Debug-only `makeDebug...` factory methods on real model/state types are allowed and encouraged when they make previews fast and readable.
- Minimal preview-only injection into views is allowed when a view otherwise owns too much state to preview directly. Prefer keeping that injection debug-only.

## User-Facing String Rule

Every user-facing string must be defined in `AirframeCaptions` and backed by Xcode-native localization resources.

- Do not define labels, titles, captions, event names, issue text, header labels, button/menu text, placeholders, empty-state text, or accessibility text in app targets, CLI targets, or domain packages.
- Use typed `AirframeCaptions` APIs from every consumer.
- Keep semantic IDs, raw log values, file names, numeric values, debug-only test names, internal IDs, and machine-readable CLI JSON keys outside the localization rule.
- Use `.xcstrings` string catalogs for localization. Do not create ad-hoc localization dictionaries as the long-term source.

## Series Presentation Rule

Every newly selectable Reader or Analysis series must define semantic classification, localized caption, physical unit, value conversion, precision, raw fallback behavior, and focused tests before it is exposed in a picker, table, graph, or human CLI output. Units belong in column or axis headers, never repeated in individual numeric cells.

## 4. Goal-Driven Execution

Define success criteria. Work in verifiable steps.

- Turn vague tasks into concrete, testable outcomes.
- For multi-step work, write a brief plan with a verification step for each item.
- Prefer checks, tests, and observable behavior over vague completion statements.
- Keep iterating until the result is verified against the stated goal.
- Every plan must follow these four principles and explicitly include them as named sections in the plan text:
  - Think Before Coding
  - Simplicity First
  - Surgical Changes
  - Goal-Driven Execution

## Compact Output Style

Use Caveman Lite for plans, status updates, code-review summaries, and other operational output.

- Prefer short, dense statements over conversational framing.
- Remove filler, pleasantries, and unnecessary recap.
- Keep grammar readable and professional.
- Use bullets and short sections when they improve scanability.
- Keep code, commands, file paths, URLs, version numbers, and identifiers exact.
- Preserve correctness and nuance when compression would make the result ambiguous.
- This is a compact style guideline, not exaggerated caveman speech. Clarity wins over maximum compression.
# Commit Messages

- Do not use Conventional Commit prefixes such as `fix:`, `feat:`, `chore:`, or `refactor:`. Write concise imperative commit subjects without a type prefix.
