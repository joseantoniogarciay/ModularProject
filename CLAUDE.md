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
- **Linking**: static by default. Module targets use `product: .staticFramework` (via the `Project.framework` helper). SPM dependencies are pinned to static via `productTypes` in `Tuist/Package.swift` (e.g. `"Alamofire": .staticFramework`). Switch a target or dep to dynamic only with a written reason in the PR description — typical valid reasons: runtime-loaded plugin/bundle, vendor SDK that ships dynamic-only, deliberate launch-time deferment of a heavy framework.
- **Build system**: Tuist 4 (workspace is generated). Do not edit `.xcodeproj` files by hand: change `Project.swift` / helpers and regenerate with `tuist generate`. Source files under a target's `Sources/` are exposed via `buildableFolders` (Xcode 16 synchronized root groups), so **adding or removing `.swift` files does NOT require `tuist generate`** — Xcode picks them up automatically on the next build. Regenerate only when manifests (`Project.swift`, `Workspace.swift`), helpers (`Tuist/ProjectDescriptionHelpers/*`), SPM dependencies (`Tuist/Package.swift`), or resource folders change.
- **Tuist version is pinned** in `.mise.toml`. Anyone cloning with `mise` installed gets the right version automatically. Without `mise`, use the version declared in that file.
- **Lint**: SwiftLint, fetched via SPM (`Tuist/Package.swift`). Run `tuist install` after cloning so the binary is available at `Tuist/.build/artifacts/swiftlint/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint`. Every target has a pre-build Run Script that lints its `Sources/`. Rules live in `.swiftlint.yml` at repo root.

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
- **Data**: depends on `Core` and `Networking`. Holds DTOs and repository implementations.
- **SharedUI**: depends on nothing (UIKit only). Reusable UIKit components consumed by Features.
- **Features/<X>**: depends only on `Core` and `SharedUI`. **Never** depends on `Networking`, `Data`, or another Feature.
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
- Asset access: always use the Tuist-synthesized accessor (`CoreAsset.background.color`, `CoreAsset.logo.image`, etc.), never `UIColor(named:)`, `UIColor(resource:)` or any other stringly-typed/Xcode-generated alternative. Xcode auto-emits its own `ColorResource` / `ImageResource` symbols in DerivedData but they are `internal` to the module and not usable across modules — Tuist's accessor is the only public, cross-module-safe path.
- Localized strings: format is **`.strings` legacy** (`<Module>/Resources/<locale>.lproj/Localizable.strings`), not `.xcstrings`. Reason: Tuist's resource synthesizer generates a public `<Module>Strings` enum for `.strings` files (e.g. `CoreStrings.welcomeTitle`) but does not synthesize for `.xcstrings`, and Xcode's native string symbol generation is `internal`-only — so `.xcstrings` would break cross-module access. Always access strings via `<Module>Strings.<key>`. Never `NSLocalizedString`, never `String(localized:)`. Supported locales: `en` (development region) and `es`.
