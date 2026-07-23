# Current Plan

This file contains only the current approved work plan. Completed implementation histories belong in Git, not here.

## Think Before Coding

- Current product work is in planning mode unless the user explicitly requests implementation.
- Treat `Airframe/` as the public project repository and the workspace root as private project context.
- Treat all Blackbox input as untrusted.
- Check current code and tests before relying on an older design note.
- Surface unresolved product or architecture choices instead of silently expanding scope.

## Simplicity First

- Keep one canonical home for each kind of durable context:
  - `MEMORY.md`: stable decisions and constraints.
  - `ARCHITECTURE.md`: current technical shape and boundaries.
  - `RESEARCH.md`: external facts and source findings.
  - `TASKS.md`: approved or genuinely unresolved near-term work.
  - `BACKLOG.md`: unapproved future ideas.
  - `TOOLING.md`: repeatable commands and learned workflow corrections.
- Use Git history for completed plans, diffs, commits, and verification transcripts.
- Do not preserve implementation diaries in `.agents/`.

## Surgical Changes

- Update only the document that owns the changed information.
- Replace superseded statements instead of appending another dated correction.
- Keep short cross-references when a fact is owned elsewhere; do not copy the fact.
- Do not modify reference submodules.
- Commit inside `Airframe/` only with explicit user approval.

## Goal-Driven Execution

Current documentation-maintenance success criteria:

1. Each `.agents` file has one clear purpose.
2. Active decisions remain available after context loss.
3. Completed implementation logs and obsolete handoffs are removed.
4. Contradictory current/superseded statements are eliminated.
5. Future updates can replace concise facts without growing another timeline.

For future implementation work, replace this section with the current approved objective, scoped files, ordered execution steps, and verification commands. Keep all four named sections.
