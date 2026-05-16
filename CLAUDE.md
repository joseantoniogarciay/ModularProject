# ModularProject

## Documentation language

**All content in this file must be written in English only.** Any note, rule, or section added later must be in English, regardless of the language the conversation is happening in. Translate before writing.

## Stack & non-negotiable rules

- **UI**: UIKit, programmatic. No SwiftUI. No XIBs or storyboards unless the user explicitly asks for them.
- **Persistence**: no CoreData. If persistence is needed, propose an alternative before implementing.
- **Language**: Swift 6 (`SWIFT_VERSION = 6.0`).
- **Concurrency**:
  - `SWIFT_STRICT_CONCURRENCY = complete` (full data-race safety).
  - `SWIFT_APPROACHABLE_CONCURRENCY = YES` (Approachable Concurrency from Xcode 26).
- **iOS deployment target**: 16.0.
- **Build system**: Tuist 4 (workspace is generated). Do not edit `.xcodeproj` files by hand: change `Project.swift` / helpers and regenerate with `tuist generate`.
- **Tuist version is pinned** in `.mise.toml`. Anyone cloning with `mise` installed gets the right version automatically. Without `mise`, use the version declared in that file.

## Modular architecture

```
ModularProject/
├── App/              # App target (UIKit). Composition root: wires DI.
├── Core/             # Framework. Contracts (protocols) + Sendable models + pure utilities.
├── Networking/       # Framework. Implements APIClient (from Core) with URLSession.
├── Features/         # One folder per feature. Each feature owns its Project.swift.
├── Tuist/
│   └── ProjectDescriptionHelpers/Module.swift   # Project.framework helper + Settings.modular
├── Workspace.swift
└── .claude/skills/   # Local Claude Code skills.
```

### Dependency rules

- **Core**: depends on nothing. Does not import UIKit or Networking.
- **Networking**: depends only on `Core`.
- **Features/<X>**: depends only on `Core`. **Never** depends on `Networking` or another Feature.
- **App**: depends on everything. The only place where concrete implementations are instantiated (DI).

### How to add a Feature

1. Create `Features/<Name>/Project.swift` with `Project.framework(name: "<Name>", dependencies: [.project(target: "Core", path: "../../Core")])`.
2. Create `Features/<Name>/Sources/`.
3. Run `tuist generate`.

### How to add a contract

It goes in `Core/Sources/` as `protocol X: Sendable`. The implementation lives in the relevant module (Networking, Persistence, etc.). Wiring happens in `App`.

## Common commands

```bash
tuist generate                # regenerate workspace
tuist generate --no-open      # without opening Xcode
tuist clean                   # clear generation cache
xcodebuild -workspace ModularProject.xcworkspace -scheme App \
  -destination 'generic/platform=iOS Simulator' build
```

## Code conventions

- Commit messages in English.
- Public types crossing module boundaries: `Sendable` whenever possible.
- `@MainActor` only when the type is genuinely UI-bound. Justify in review.
- Prefer `actor` for shared mutable state over locks/queues.
- Do not use `@unchecked Sendable` or `nonisolated(unsafe)` without a documented invariant and a removal plan.
