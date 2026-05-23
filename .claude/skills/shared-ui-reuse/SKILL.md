---
name: shared-ui-reuse
description: Enforce reuse of components and helpers from the SharedUI module whenever you write or edit UIKit code in this project. Apply when adding a new feature view, creating a new UITableView/UICollectionView cell, writing layout constraints, registering or dequeuing reusable cells, or spotting a UI pattern that repeats across features. Trigger on any `NSLayoutConstraint.activate([...])` block, on `translatesAutoresizingMaskIntoConstraints = false`, or on subclassing `UIView`/`UIViewController`/`UITableViewCell`/`UICollectionViewCell`.
---

# SharedUI reuse

`SharedUI` is the project's UIKit toolbox: AutoLayout helpers, reusable cells, and common views. Every feature that touches UIKit must reuse what is already there instead of redoing it, and must promote new repeating patterns into the module.

## How SharedUI/Sources is organized

```
SharedUI/Sources/
├── Cells/        — reusable UITableView/UICollectionView cells.
├── Views/        — reusable UIView subclasses (error/empty states, banners, ...).
└── Extensions/   — UIKit extensions (layout helpers, conveniences).
```

When adding a new reusable type, place it in the matching subfolder. If a new role appears (e.g. controllers, configurations), create a new subfolder rather than mixing.

## What lives in SharedUI today

### Layout helpers — `SharedUI/Sources/Extensions/UIView+AutoLayout.swift`

| Helper | Use when |
|---|---|
| `view.pinEdges(to: parent, insets:)` | Filling a parent view (e.g. a `UITableView` inside the controller's `view`). |
| `view.pinSize(_:)` | Square fixed-size view (icons, square images). |
| `view.pinSize(width:height:)` | Fixed width and height with different values. |
| `view.centerInSuperview()` | Single child centered in its immediate superview (spinners, error icons). |

Each helper sets `translatesAutoresizingMaskIntoConstraints = false` on the receiver. **Do not set it manually for views that are fully constrained via a helper** — it is redundant and a code-review smell.

### Reusable cells — `SharedUI/Sources/Cells/`

| Cell | Use when |
|---|---|
| `LoaderCell` | Pagination footer or any "loading more" indicator in a `UITableView`. Dequeue with `LoaderCell.reuseID`. |
| `RetryCell` | Inline pagination-error row at the bottom of a `UITableView`. Shows a message and a retry button. Dequeue with `RetryCell.reuseID`. Configure via `configure(message:retryTitle:onRetry:)`. |

**Cell background:** Always set `backgroundColor = .clear` in `setupViews()`. UITableViewCell defaults to `.systemBackground` (white); without this the cell shows a white box in `CellPreview` previews and can look wrong on grouped/insetGrouped table views whose background shows around rows. The table view manages the per-row background — the cell itself should be transparent.

### Reusable views — `SharedUI/Sources/Views/`

| View | Use when |
|---|---|
| `RetryView` | Full-screen error state for a failed load with a single retry action. Configure via `configure(message:retryTitle:)`, set `delegate` to a `RetryViewDelegate`. The view is opaque — it does NOT classify the error itself; the consumer translates `Error` → message (e.g. `NetError.noConnection` → "No internet connection…", anything else → "Something went wrong…"). |

## Localized strings in UIKit code

**Every user-facing string in UIKit code must be localized** through Tuist's synthesized `<Module>Strings.<key>` accessor. Never `NSLocalizedString`, never `String(localized:)`, never an inline literal in a `UILabel`, `UIButton` title, alert message, or anything else the user reads.

The rule applies to every UIKit type — views in `SharedUI`, cells, view controllers in features, alerts presented from anywhere. If you find yourself typing a string literal that will end up on screen, stop and add the key to the right `.strings` file first.

Where strings live:

- **Shared across multiple features** (retry-button title, common error messages, "Cancel" / "Done", etc.) → `Core/Resources/<locale>.lproj/Localizable.strings`. Accessor: `CoreStrings.<key>`.
- **Specific to a single feature** (a screen title only that feature uses, a feature-specific empty-state copy) → `Features/<X>/Resources/<locale>.lproj/Localizable.strings`. Accessor: `<X>Strings.<key>`. (When a feature needs its first localized string, set up its `Resources/` folder via Tuist.)

Workflow when adding or renaming a key:

1. Add the key to **every** supported locale's `.strings` file at once (`en` and `es`). Missing locales silently fall back to the key name.
2. Run `tuist generate` once — the synthesized `<Module>Strings` enum updates with the new property.
3. Use it at call sites: `CoreStrings.errorNoConnection`.

`SharedUI` reusable components (e.g. `RetryView`) may carry an **English default** at the API surface so they compile and preview in isolation, but the consumer is expected to **always pass the localized override** at configure time. The default is a fallback, not the production string.

Strings that are NOT user-facing — log messages, accessibility identifiers used as test selectors, OSLog categories, asset names — are exempt. The rule is about copy that reaches the user's eyes.

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

Previews in this project are **mandatory** for every file that contains a `UIViewController` or `UIView` subclass. Every view file must have at least one `#Preview` block at the bottom of the same file. The only exceptions are pure-plumbing types with no visual output (coordinators, delegates, data sources with no layout code).

The `#Preview` macro supports returning `UIView` and `UIViewController` directly since iOS 17 / Xcode 15. The macro itself lives in `DeveloperToolsSupport`, but its expansion references SwiftUI types internally — so **`import SwiftUI` is required** even when the preview returns UIKit. Put it inside the `#if DEBUG` block so it never reaches Release.

If you skip the import, modules that happen to pull SwiftUI in transitively (e.g. `Features/Pokemon` via Kingfisher) may compile previews anyway, but modules that don't (e.g. `SharedUI`, which only depends on UIKit) will fail with `Compiling failed: no such module 'SwiftUI'`. Importing explicitly inside `#if DEBUG` makes the file robust regardless of the module's dep graph and costs zero in Release.

The deployment target of this project is iOS 17, so **no `@available(iOS 17.0, *)` annotation is needed** in front of `#Preview`. (The annotation was historically required when the deployment was iOS 16, because the UIKit-returning overload of `#Preview` is iOS 17+. Now that the target is 17, the overload is always available and the annotation only adds noise.)

Hard rules when you DO write a preview:

1. **Wrap the preview in `#if DEBUG`** so it never compiles into Release builds.
2. **`import SwiftUI` inside that `#if DEBUG` block**, regardless of what the preview returns. Without it the macro's expansion will not resolve in any module that lacks a transitive SwiftUI import.
3. **Place the preview at the bottom of the same file** as the type it previews — close to the code being previewed, no separate `*+Previews.swift` files.

### Cell previews — always go through `CellPreview`

Pattern for a `UITableViewCell` or `UICollectionViewCell` preview — wrap the configured cell in `CellPreview` (in `SharedUI/Sources/Preview/CellPreview.swift`) and return that:

```swift
#if DEBUG
import SwiftUI

#Preview("My Cell") {
    let cell = MyCell(style: .default, reuseIdentifier: nil)
    cell.configure(with: SampleModel.preview)
    return CellPreview(cell, height: 80)
}
#endif
```

**Why not return the cell directly.** Returning a bare `UIView` from `#Preview` makes the Xcode canvas treat that view as the root of the preview viewport, and it gets stretched to fill the entire simulator window (the `cell.frame = CGRect(...)` you might be tempted to set is overwritten by the canvas). The result is a cell whose `contentView` is hundreds of points tall, with the labels flying to opposite edges because their `topAnchor`/`bottomAnchor`/`centerYAnchor` constraints resolve against that giant frame — nothing like how the cell will actually render inside a `UITableView` row.

`CellPreview` is a thin SwiftUI wrapper (`UIViewRepresentable` + `.frame(width:height:)` + padding + grouped background) that gives the cell a fixed-size container — SwiftUI honors the `.frame()` and the cell renders at realistic proportions, centered in the canvas with empty space around it. `width` defaults to 375 (iPhone-ish content width); **always pass `height`** — `UITableViewCell` has no SwiftUI-visible intrinsic content size, so `height: nil` causes the cell to expand and fill the entire preview canvas instead of rendering at a realistic row height. Typical values: fixed-height utility cells (spinner-only, etc.) → their minimum height constant (e.g. `56`); content cells → match their `estimatedRowHeight` (e.g. `80`).

**Anti-patterns:**

```swift
// ❌ Returning the cell directly — stretched to the whole canvas
#Preview("My Cell") {
    let cell = MyCell(style: .default, reuseIdentifier: nil)
    cell.frame = CGRect(x: 0, y: 0, width: 375, height: 80)   // overwritten by the canvas
    cell.configure(with: SampleModel.preview)
    return cell
}

// ❌ Hand-rolling a UIView host every time
#Preview("My Cell") {
    let cell = MyCell(...)
    let host = UIView()
    host.addSubview(cell)
    // … 6 lines of constraints, slightly different each time, no padding, no background
    return host
}

// ✅ Use the shared wrapper
#Preview("My Cell") {
    let cell = MyCell(style: .default, reuseIdentifier: nil)
    cell.configure(with: SampleModel.preview)
    return CellPreview(cell, height: 80)
}
```

Pattern for a `UIViewController` preview that needs an injected protocol (repository, use case, etc.):

```swift
#if DEBUG
import SwiftUI

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

The `PreviewSomethingRepository` fake should be **feature-local**, not in Core. If a single feature has two or more previews that share the same fake, extract it to its own file in the feature (e.g. `Features/X/Sources/PreviewSomethingRepository.swift`, gated by `#if DEBUG`) and let every preview in that feature use it. Do not promote the fake to `Core` or `SharedUI` — preview data is not domain data.

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
- **Setting `contentView.backgroundColor` or `backgroundColor` on a `UITableViewCell` that has an accessory view (`accessoryType`, `accessoryView`).** The accessory area is outside `contentView` and rendered using the cell's `backgroundConfiguration`, which takes precedence over `backgroundColor` in iOS 14+. Correct approach: `var config = UIBackgroundConfiguration.listPlainCell(); config.backgroundColor = <color>; backgroundConfiguration = config`. This colors both `contentView` and the accessory area atomically.
- **Setting `view.backgroundColor` on the view controller but not on the `UITableView`, `UIScrollView`, or `UICollectionView` that fills it.** These scrollable containers have their own independent `backgroundColor` (defaults to `.systemBackground`/white) that covers the controller's `view` entirely. Whenever you set a background color on a view controller's `view`, set the same color on every full-screen scrollable container inside it. Example: if `view.backgroundColor = CoreAsset.background.color`, also set `tableView.backgroundColor = CoreAsset.background.color` and `scrollView.backgroundColor = CoreAsset.background.color`.

## Not a violation (false positives to avoid)

These patterns **look** like SharedUI under-use at first glance but are correct under the rules above. Do not flag them in audits or "fix" them.

- **`view.translatesAutoresizingMaskIntoConstraints = false` followed by an explicit `NSLayoutConstraint.activate([...])` block** where the constraints reference `layoutMarginsGuide`, `safeAreaLayoutGuide`, `readableContentGuide`, a sibling view's anchor, or only a subset of edges. The manual line is **required** here — no helper applies, and forgetting it breaks the layout. The rule against setting it manually only applies *next to a helper call*.
- **A view that uses `pinSize`/`pinEdges`/`centerInSuperview` for one axis and explicit constraints for another** (e.g. `imageView.pinSize(60)` plus an explicit `leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor)`). Mixing is fine — the helper covers what it covers, and the explicit block handles the exceptions.
- **A cell or view that subclasses `UITableViewCell` / `UIView` and writes its own `setupViews()` with raw constraints**, when the constraints fall into the exception list (sibling anchors, margins guide, priorities, animation references). Subclassing UIKit types is not a violation by itself; only *re-implementing functionality that already exists in SharedUI* is.
- **A feature view controller that writes `NSLayoutConstraint.activate([...])` against `view.safeAreaLayoutGuide.topAnchor` or `view.layoutMarginsGuide.leadingAnchor`.** These are explicit by design — there is no `pinEdges(to: safeArea)` helper, and adding one would not simplify the call site enough to be worth a separate API.

Before flagging a `translatesAutoresizingMaskIntoConstraints = false` or an `NSLayoutConstraint.activate([...])` block: **look at the anchors in the block**. If any anchor matches an exception above, the explicit form is correct.

## Content margins

**All scrollable content containers must have at least 24 pt of horizontal padding on both sides.** A plain `UIView` used as a scroll view's content view has 8 pt `layoutMargins` by default — that is too tight. Always override it explicitly:

```swift
contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
```

Then constrain the content stack to `contentView.layoutMarginsGuide` as usual. Never rely on the system default 8 pt for content regions. The 24 pt value is the project minimum; wider is acceptable for specific designs, narrower is not.

This rule applies to every `UIScrollView` content container in features, regardless of screen type (forms, detail screens, profile pages, etc.).

## Color tokens — never use UIKit system colors directly

**All background and fill colors in UIKit code must come from `CoreAsset.<token>.color`.** Never reference `.systemBackground`, `.secondarySystemBackground`, `.tertiarySystemBackground`, `.systemFill`, `.secondarySystemFill`, `.tertiarySystemFill`, `.quaternarySystemFill`, or any other `UIColor` system semantic. These colors ignore the project's palette and produce visually inconsistent results (e.g. a cold blue-gray card on a warm-cream background).

### Token catalogue

| Token | Accessor | Use when |
|---|---|---|
| Background | `CoreAsset.background.color` | Page / screen background. Views that fill the screen (`view`, `tableView`, `scrollView`). |
| CardBackground | `CoreAsset.cardBackground.color` | Card surface sitting on top of the page background (cells, metric panels, floating containers). |
| StatTrack | `CoreAsset.statTrack.color` | Track background for progress/stat bars. |
| Text | `CoreAsset.text.color` | Primary body text. |
| SecondaryText | `CoreAsset.secondaryText.color` | Labels, captions, and icons that should recede visually. |

### Adding a new color token

When a new UI color is needed that has no existing token:

1. Create `Core/Resources/Assets.xcassets/<Name>.colorset/Contents.json` with light and dark variants tuned to the project palette (warm cream `#F5F1EB` / dark blue-gray `#1B1B22`). Do not copy iOS system color values — derive values that harmonize with the existing tokens.
2. Run `tuist generate --no-open` so the synthesized `CoreAsset.<name>` accessor is available.
3. Use `CoreAsset.<name>.color` at every call site.

### Common failure modes

- **`backgroundColor = .secondarySystemBackground`** → use `CoreAsset.cardBackground.color`.
- **`backgroundColor = .quaternarySystemFill`** → use `CoreAsset.statTrack.color`.
- **Any `UIColor.system*` or `UIColor.*SystemBackground`** → always map to a `CoreAsset` token instead.

## Non-goals

This skill does not cover:

- General UIKit-only-no-storyboard style (see `CLAUDE.md` → "Stack & non-negotiable rules").
- Static linking, Tuist generation, or module boundaries beyond SharedUI (see `CLAUDE.md`).
- Asset access via `CoreAsset` / per-module synthesized accessors (see `CLAUDE.md` → "Code conventions").
- Localized strings via `<Module>Strings` (see `CLAUDE.md` → "Code conventions").
- Concurrency annotations on UIKit types — covered by the existing concurrency skill.
