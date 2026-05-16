---
name: shared-ui-reuse
description: Enforce reuse of components and helpers from the SharedUI module whenever you write or edit UIKit code in this project. Apply when adding a new feature view, creating a new UITableView/UICollectionView cell, writing layout constraints, registering or dequeuing reusable cells, or spotting a UI pattern that repeats across features. Trigger on any `NSLayoutConstraint.activate([...])` block, on `translatesAutoresizingMaskIntoConstraints = false`, or on subclassing `UIView`/`UIViewController`/`UITableViewCell`/`UICollectionViewCell`.
---

# SharedUI reuse

`SharedUI` is the project's UIKit toolbox: AutoLayout helpers, reusable cells, and common views. Every feature that touches UIKit must reuse what is already there instead of redoing it, and must promote new repeating patterns into the module.

## What lives in SharedUI today

### Layout helpers — `SharedUI/Sources/UIView+AutoLayout.swift`

| Helper | Use when |
|---|---|
| `view.pinEdges(to: parent, insets:)` | Filling a parent view (e.g. a `UITableView` inside the controller's `view`). |
| `view.pinSize(_:)` | Square fixed-size view (icons, square images). |
| `view.pinSize(width:height:)` | Fixed width and height with different values. |
| `view.centerInSuperview()` | Single child centered in its immediate superview (spinners, error icons). |

Each helper sets `translatesAutoresizingMaskIntoConstraints = false` on the receiver. **Do not set it manually for views that are fully constrained via a helper** — it is redundant and a code-review smell.

### Reusable cells — `SharedUI/Sources/LoaderCell.swift`

| Cell | Use when |
|---|---|
| `LoaderCell` | Pagination footer or any "loading more" indicator in a `UITableView`. Dequeue with `LoaderCell.reuseID`. |

## When to use the helpers (and when not)

Use them whenever the layout pattern matches exactly:

- ✅ `pinEdges` whenever you would write four constraints pinning `top`/`leading`/`trailing`/`bottom` to the same parent.
- ✅ `pinSize` whenever you would write `widthAnchor` + `heightAnchor` constraints with constants.
- ✅ `centerInSuperview` whenever you would write `centerX` + `centerY` against the immediate superview.

Keep an explicit `NSLayoutConstraint.activate([...])` for any of the following:

- ❌ Constraints that reference `layoutMarginsGuide`, `safeAreaLayoutGuide`, `readableContentGuide`, or any non-edge anchor.
- ❌ Constraints against a sibling view's anchor (e.g. `nameLabel.leading == imageView.trailing + 16`).
- ❌ Constraints with priority < 1000.
- ❌ Constraints you need to keep a reference to (animation, runtime mutation).
- ❌ One-off layouts where forcing a helper makes the code harder to read.

The helpers are a shortcut for the common case, not a replacement for AutoLayout. If two different rules apply, write the explicit block.

## When a pattern repeats

If you find yourself writing the same multi-constraint block in two different features, **promote it to a helper** in `SharedUI/Sources/UIView+AutoLayout.swift` (or a new file under `SharedUI/Sources/` if it does not fit there). Copy-pasting layout code across features is a defect.

A new helper must:

- Be generic — no feature-specific names, no assumptions about a particular hierarchy.
- Set `translatesAutoresizingMaskIntoConstraints = false` on the receiver if it adds constraints to it.
- Be declared `public`.
- Carry a one-line comment only if behavior is non-obvious. No `// pin edges` over `func pinEdges`.

## Adding a new reusable component

A cell, view, or component that two or more features could use goes in `SharedUI/Sources/`. Until the second consumer exists, keep it inside the originating feature module. Premature promotion to `SharedUI` (i.e. before a second consumer is known) is a smell — the API tends to be wrong because it was designed with only one use case in mind.

When promoting, expose only the surface the second consumer actually needs. Move the type to `SharedUI/Sources/`, mark it `public`, and update the feature to import `SharedUI` and use the public symbol. Do not leave behind a wrapper in the feature unless adapting the API is genuinely required.

## Xcode previews for UIKit

The `#Preview` macro supports returning `UIView` and `UIViewController` directly since iOS 17 / Xcode 15 — **no `import SwiftUI` is required**. The macro lives in `DeveloperToolsSupport`, not in `SwiftUI`; only previews that return a SwiftUI `View` need to import `SwiftUI`.

Two rules to keep previews compiling without ceremony:

1. **Annotate with `@available(iOS 17.0, *)`** even if your deployment target is lower. The UIKit-returning overload of `#Preview` is iOS 17+. Without the annotation, the macro falls back to the SwiftUI `View` overload, which uses `ViewBuilder` and rejects explicit `return` statements — you'll see "cannot use explicit 'return' statement in the body of result builder 'ViewBuilder'". The annotation is fine because previews are dev-only and Xcode runs them on iOS 17+ simulators.
2. **Wrap previews in `#if DEBUG`** so they never compile into Release builds. Place them at the bottom of the same file as the type they preview — close to the code being previewed, no separate `*+Previews.swift` files needed.

Pattern for a `UITableViewCell` preview:

```swift
#if DEBUG
@available(iOS 17.0, *)
#Preview("My Cell") {
    let cell = MyCell(style: .default, reuseIdentifier: nil)
    cell.frame = CGRect(x: 0, y: 0, width: 375, height: 80)
    cell.configure(with: SampleModel.preview)
    return cell
}
#endif
```

Pattern for a `UIViewController` preview that needs an injected protocol (repository, use case, etc.):

```swift
#if DEBUG
private struct PreviewSomethingRepository: SomethingRepository {
    func list(...) async throws -> [Something] {
        // Return hardcoded data, no network.
    }
}

@available(iOS 17.0, *)
#Preview("My Screen") {
    UINavigationController(
        rootViewController: MyViewController(
            repository: PreviewSomethingRepository(),
            onSelect: { _ in }
        )
    )
}
#endif
```

The fake impl lives `private` next to the preview. If you find yourself duplicating it across previews in different files, promote it to a shared `Preview*` factory inside the same feature module (still gated by `#if DEBUG`, still feature-local — do not promote to Core).

## Where SharedUI sits in the dependency graph

- `SharedUI` depends on nothing — UIKit only.
- `Features/<X>` depend on `Core` and `SharedUI` (rule documented in `CLAUDE.md`).
- `Networking`, `Data`, and `App` do not import `SharedUI`. SharedUI is consumed by features, not by data/transport modules.

If a non-feature module ever needs a UIKit helper, that is a signal the helper might not belong in `SharedUI` after all — pause and rethink before adding the import.

## Common failure modes

- **Writing `NSLayoutConstraint.activate([...])` for an edge-pinning case.** Fix: use `pinEdges`.
- **Setting `translatesAutoresizingMaskIntoConstraints = false` manually next to a `pinEdges`/`pinSize`/`centerInSuperview` call.** Fix: remove the manual line; the helper does it.
- **Building a one-off "loading footer cell" inside a feature.** Fix: register and dequeue `LoaderCell` from `SharedUI`.
- **Copying layout patterns verbatim between two features.** Fix: promote to a `SharedUI` helper before the second feature ships.
- **Importing `SharedUI` and still writing raw constraints for cases listed in the helpers table above.** Fix: review the table; refactor.
- **Adding a feature-specific helper to `SharedUI` because it "kind of fits".** Fix: keep it in the feature until a second use case shows up.

## Non-goals

This skill does not cover:

- General UIKit-only-no-storyboard style (see `CLAUDE.md` → "Stack & non-negotiable rules").
- Static linking, Tuist generation, or module boundaries beyond SharedUI (see `CLAUDE.md`).
- Asset access via `CoreAsset` / per-module synthesized accessors (see `CLAUDE.md` → "Code conventions").
- Localized strings via `<Module>Strings` (see `CLAUDE.md` → "Code conventions").
- Concurrency annotations on UIKit types — covered by the existing concurrency skill.
