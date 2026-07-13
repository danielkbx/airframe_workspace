# Agent Instructions

This workspace is the private Airframe wrapper repository. It uses `.agents/` for durable project context.

Repository layout:

- Root repository: private workspace repo, `git@github.com:danielkbx/airframe_workspace.git`.
- `Airframe/`: public Airframe submodule, `git@github.com:danielkbx/airframe.git`.
- `blackbox-log-viewer/`: upstream reference submodule, `git@github.com:betaflight/blackbox-log-viewer.git`.
- `betaflight/`: upstream reference submodule, `git@github.com:betaflight/betaflight.git`.
- `.agents/`: private durable project context tracked only in the root workspace repo.

Git safety rules:

- Root workspace commits may be short, frequent, and attribution-free.
- Commit inside `Airframe/` only with explicit user approval and with the stricter Airframe message rules.
- Never commit or push inside `blackbox-log-viewer/` or `betaflight/`; only fetch or pull them.
- A changed submodule pointer is committed in the root repo only when the new referenced commit should be synchronized across machines.
- Always check which repository owns the current directory before git commit, push, or status-sensitive work.

Before doing any work in this workspace, read:

1. `.agents/README.md`
2. `.agents/MEMORY.md`
3. `.agents/RESEARCH.md`
4. `.agents/ARCHITECTURE.md`
5. `.agents/TASKS.md`
6. `.agents/TOOLING.md`
7. `.agents/PLAN.md`
8. `.agents/PRINCIPLES.md`
9. `.agents/BACKLOG.md`

The upstream reference repositories are cloned in `blackbox-log-viewer/` and `betaflight/`. Do not modify them unless the user explicitly asks for changes there.

Maintain the `.agents/` files proactively. When new stable information, rules, decisions, constraints, goals, risks, or project direction emerge, update the relevant `.agents/*.md` file during the same turn. This project is expected to hit context-window limits often, so durable context must not depend on chat history.

Maintain `.agents/TOOLING.md` as a self-learning knowledge base. Whenever tool usage reveals a faster or more reliable workflow, or a command had to be corrected to work properly, record the lesson there without waiting for the user to ask.

Follow `.agents/PRINCIPLES.md` for all plans, implementations, reviews, and status updates. Every plan must follow and explicitly include the four named sections in its text: Think Before Coding, Simplicity First, Surgical Changes, and Goal-Driven Execution.

Use `.agents/BACKLOG.md` to capture ideas that should not be lost but are not current approved scope.

Current project direction:

- Planning phase only unless the user asks for implementation.
- Project/app name: Airframe.
- Product subtitle: A Blackbox Log Analyzer.
- Target idea is a fully native Swift iOS/macOS Universal app for Betaflight Blackbox logs.
- Parser and model should be Swift-native.
- Data/model and UI should be separated, likely through Swift Packages.
- GPL-3.0 is acceptable.
- App Store distribution is optional.
- Do not introduce external dependencies without the user's explicit approval.
- Project language is English for all code, variables, documentation, agent files, comments, commit text, and project artifacts, even when the chat conversation is in German.
- Use Semantic Versioning.
- All Swift Packages and every Xcode target must always share the same version number.
- Xcode targets should get the shared version through xcconfig files.
- `Base.xcconfig` contains `MARKETING_VERSION`; other xcconfig files may include `Base.xcconfig`.
- Use Swift 5.9 as the Swift language version; avoid Swift 6 language mode unless the user explicitly changes this decision.
- Build targets may use the latest stable iOS and macOS releases.
- Prefer modern Swift idioms, including enums with associated values where they model the domain well.
- Prefer async/await and structured concurrency over completion blocks.
- Prefer one-line calls and function declarations when they fit within 150 characters.
- Use modern Swift Testing for package tests unless a specific XCTest-only capability is required.
- Prefer namespacing with nested types where it improves clarity, e.g. `Parser.Result` instead of a broad standalone `ParserResult`.
- Put each large type in its own file. Small subordinate types used by a large type may live in the same file as extensions when they remain compact and local.
- If a subordinate type is used by many other types, give it its own file.
- Prefer `throws` over returning Swift `Result` values.
- When a type has domain-specific failures, attach a nested or extension-defined `Error` type with concrete cases for that type.

Swift/Xcode workflow rules:

- Prefer CLI-first workflows; use Xcode itself only for special cases.
- Use `xcodeproj` for Xcode project file work when appropriate.
- Build and test Swift Packages with `swift` and `xcodebuild`.
- Control simulators through command-line tools such as `xcrun simctl`.
- For simulator-related `xcodebuild` calls, do not pipe output to `grep`; write useful log files, wait for completion, then inspect the logs.

GitHub workflow rules:

- Use `gh` for GitHub interaction with the `danielkbx` account.
- Before every push or PR action, verify that `gh` is authenticated as the correct account (`danielkbx`).
