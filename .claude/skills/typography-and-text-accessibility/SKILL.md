---
name: typography-and-text-accessibility
description: Enforce this project's typography and text-accessibility conventions whenever you write, edit, or extend UIKit code that displays text or icon-only controls. Apply when setting `.font` on a `UILabel`, `UIButton`, `UITextField`, or any `NSAttributedString`; when creating a `UIBarButtonItem` with an SF Symbol image; when configuring `preferredSymbolConfiguration` on a `UIImageView`; when adding any animation, transition, or motion effect; or when adding a `UIImageView` that conveys semantic information (logos, sprites, badges). Also apply when the user asks "which font/size should I use", "is this text accessible", or anything about Dynamic Type, VoiceOver, or Reduce Motion. Triggers on the literal strings `UIFont.systemFont(`, `UIFont.boldSystemFont(`, `.preferredFont(forTextStyle:`, `adjustsFontForContentSizeCategory`, `UIFontMetrics`, `accessibilityLabel`, `isAccessibilityElement`, `accessibilityTraits`, `isReduceMotionEnabled`, `UIImage(systemName:`, or on any `UILabel()` / `UIButton(` instantiation without a follow-up `applyTextStyle`.
---

# Typography and text accessibility

This skill encodes two invariants that are already true everywhere in the codebase and must stay true:

1. **Every piece of text scales with Dynamic Type.** No exceptions. Hard-coded sizes that ignore the user's accessibility text setting are a bug, not a style choice.
2. **Every interactive control that conveys meaning is reachable by VoiceOver.** Icon-only buttons without an `accessibilityLabel` are a bug.

The role table below was derived by reading every text site in the project. Use it — don't invent new mappings.

## Text style → role mapping

Always pick the style from this table by semantic role, never by visual size. iOS sizes shift with the user's Dynamic Type setting; the role does not.

| Style | Role | Use for |
|---|---|---|
| `.largeTitle` | Welcome / onboarding screen title | First-screen titles when the screen has hero copy and minimal chrome (`LoggedOutViewController`, `RegisterViewController`, `LoggedInViewController` greeting). |
| `.title3` | Modal title | The headline inside a presented modal/dialog (`ConfirmationDialog`). |
| `.headline` | Primary content emphasis or CTA label | Cell name in a list, totals/subtotals, banner title, stat values, section header inside a screen, primary/outline button titles. |
| `.body` | Body copy and inputs | Long-form copy in a screen, text-field input, dialog message, empty-state message, single-value labels on a detail screen. |
| `.subheadline` | Secondary text directly below a title | Subtitle under a `largeTitle` / cart item detail row / text-link button copy. |
| `.footnote` | Inline informational copy | Banner message body, inline retry-row message. |
| `.caption1` | Metadata, captions, validation errors | Pokemon number, stat names, account caption, validation error label, custom badges/chips. |

`.title1`, `.title2`, `.callout`, `.caption2` are intentionally absent — the codebase does not use them and adding them without a current consumer creates a wider style vocabulary that becomes hard to police. If a new design genuinely needs one, add it to this table in the same change that introduces it.

## How to apply a style

Use the SharedUI helpers — they enforce both `font` and `adjustsFontForContentSizeCategory` in one call so the second is never forgotten.

```swift
nameLabel.applyTextStyle(.headline)
captionLabel.applyTextStyle(.caption1)
retryButton.applyTextStyle(.footnote)
```

| Helper | Module | Use for |
|---|---|---|
| `UILabel.applyTextStyle(_:)` | `SharedUI/Sources/Extensions/UILabel+TextStyle.swift` | Plain `UILabel`. |
| `UIButton.applyTextStyle(_:)` | `SharedUI/Sources/Extensions/UIButton+TextStyle.swift` | Plain `UIButton` (the `titleLabel?.font = …` pattern). |
| `UILabel.applyScaledFont(size:weight:relativeTo:)` | Same file as `applyTextStyle` on `UILabel` | Custom design size that must still scale with Dynamic Type. The only existing consumer is the type-chip in `PokemonDetailViewController`. |

### When the helper does NOT apply

- **`UIButton.Configuration` flows** — set the font inside the configuration's `titleTextAttributesTransformer`. Reference impl: `PrimaryButton.swift`. The helper would not be picked up because `UIButton.Configuration` rebuilds the title label each update.
- **Attributed-title flows (`setAttributedTitle`)** — set the font as part of the `NSAttributedString` attributes. Reference impl: `TextLinkButton.swift`.

In both of these cases, you still must use `.preferredFont(forTextStyle:)` for the font value and set `titleLabel?.adjustsFontForContentSizeCategory = true` on the button.

### Migrating existing call sites

The pre-existing `label.font = .preferredFont(forTextStyle: .headline)` + `label.adjustsFontForContentSizeCategory = true` pattern is **equivalent**. Don't do a bulk refactor — migrate to the helper when you touch the file for another reason.

## Dynamic Type — non-negotiable rules

These are already universal in the project. Don't be the change that breaks them.

1. **Never use `UIFont.systemFont(ofSize:)` or `UIFont.boldSystemFont(ofSize:)` directly on a label/button.** Both produce fonts that ignore the user's Dynamic Type setting.
2. **Always set `adjustsFontForContentSizeCategory = true`** on any `UILabel`, `UITextField`, or `UIButton.titleLabel`. Without it, the font is picked up once at creation and never updates when the user changes their accessibility text size while the app is running. The helpers above set it for you.
3. **Custom-sized fonts must be wrapped in `UIFontMetrics`.** When a design genuinely needs a size that `UIFont.TextStyle` does not provide (the only current case is the 12pt semibold type-chip in `PokemonDetailViewController`), use `UIFontMetrics(forTextStyle: <closest style>).scaledFont(for: base)` — or the `applyScaledFont(size:weight:relativeTo:)` helper. Pick the closest text style as the scaling reference (typically `.caption1` for chip-like labels, `.body` for body-sized custom fonts).
4. **SF Symbols also scale.** When sizing a symbol image to sit next to text, use `imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: <matching style>)` so the icon grows and shrinks with the surrounding text. Already done in `PokemonCell` (`.caption1` for the chevron) and `PokemonDetailViewController` (`.body` for metric-card icons).
5. **`numberOfLines = 0`** on every label that can wrap. At the largest Dynamic Type setting (AX5) most copy needs to wrap or it truncates. The only legitimate `numberOfLines = 1` is in chip/badge-like fixed-width contexts where wrapping would break the layout — and there you must verify visually at AX5 that the label still fits or scrolls.

## VoiceOver — text accessibility

Dynamic Type is handled by the rules above. VoiceOver is a separate axis and must be handled explicitly. The codebase is currently weak here — when you touch one of these sites, fix it.

### Icon-only `UIBarButtonItem`s

Every `UIBarButtonItem` created from an SF Symbol must declare an `accessibilityLabel`. VoiceOver otherwise reads the SF Symbol's system name (e.g. "bell badge", "rectangle portrait and arrow right"), which is not what the user expects.

Use the helper that makes the label parameter non-optional:

```swift
let logoutItem = UIBarButtonItem(
    symbolName: "rectangle.portrait.and.arrow.right",
    accessibilityLabel: AccountStrings.logoutAccessibilityLabel,
    target: self,
    action: #selector(logoutTapped)
)
```

The `accessibilityLabel` argument is user-facing copy — **it must be a localized string** (`<Module>Strings.<key>`), not a literal. Add the key to every supported locale's `.strings` file at once (see `shared-ui-reuse` skill for the workflow).

The same rule applies to any `UIButton` that has only an image and no title.

### `UIImageView` with semantic content

A `UIImageView` that conveys meaning (logo, sprite, badge color, photo of the user, …) must be either:

- **Accessible with a label**: `imageView.isAccessibilityElement = true; imageView.accessibilityLabel = <localized>` — for images whose meaning is not redundantly stated by an adjacent label. The hero logo on the LoggedOut screen, for instance.
- **Hidden from VoiceOver**: `imageView.isAccessibilityElement = false` — for purely decorative icons that sit next to a text label that already says the same thing (the metric-card icon next to the value+title labels in `PokemonDetailViewController`, the chevron in `PokemonCell`, the placeholder photo glyph on a Pokemon sprite when the actual sprite is loading).

Choose one explicitly. The UIKit default is "VoiceOver picks something up from the underlying `UIImage`", which is usually neither useful nor what you want.

### Composite custom views (badges, cards)

When you build a custom view that aggregates multiple labels and icons into one logical unit (the type-chip in `PokemonDetailViewController`, the metric-card, the Pokemon sprite cell), set `isAccessibilityElement = true` on the container and provide a single `accessibilityLabel` that reads the whole thing as one phrase. VoiceOver users do not want to swipe through "Stat", "HP", "45" as three separate elements.

For interactive composites (a tappable card), also set `accessibilityTraits = .button`.

### Visual links that are buttons

`TextLinkButton` looks like a hyperlink but is a `UIButton`. Set `accessibilityTraits = .link` (or `[.link, .button]`) so VoiceOver announces it as a link, not a generic button.

### Accessibility identifiers (for UI tests)

`accessibilityIdentifier` is NOT user-facing — it is for `XCUIElement` lookup in UI tests. Don't confuse it with `accessibilityLabel`. Set identifiers on elements that UI tests need to find; the project does not currently use this so there is no mandate, only a reminder that the two properties exist for different reasons.

## Reduce Motion

Any animation longer than a state change (fade transitions, slide-ins, custom dialog presentations, Kingfisher's `.transition(.fade(…))` on remote images) must respect the user's Reduce Motion setting:

```swift
if UIAccessibility.isReduceMotionEnabled {
    // perform the change without animation
    view.alpha = 1
} else {
    UIView.animate(withDuration: 0.2) { view.alpha = 1 }
}
```

For Kingfisher, pass `.transition(.none)` when Reduce Motion is on. The fade transition introduced in commit `6ae61d4` must be gated this way before it can claim to be accessible.

For modal presentations that use a custom slide/scale animation (`ConfirmationDialog`), provide a non-animated fallback when Reduce Motion is enabled — usually a plain `alpha`/`isHidden` flip.

The `UIAccessibility.reduceMotionStatusDidChangeNotification` fires when the user toggles the setting while the app is running; observe it if your view persists across that change.

## Color contrast

When you set both a text color and a background color manually (as in the type-chip — `.white` text on `typeColor(for: type)`), verify the pair meets WCAG AA contrast at minimum (4.5:1 for body, 3:1 for ≥18pt or bold-≥14pt text). The colors derived from `typeColor("electric")` / `typeColor("ice")` (yellow / pale blue) with white text very likely fail AA — pick a darker base, or switch the text to black for those specific types.

Color tokens from `SharedUIAsset` (text, secondaryText, background, cardBackground) are designed to harmonize and are not a contrast concern. Manual color overrides are.

## Anti-patterns

- **`label.font = UIFont.systemFont(ofSize: 14)`** without `UIFontMetrics`. Fix: pick the right `UIFont.TextStyle` from the role table and use `applyTextStyle(_:)`. If the design genuinely needs a custom size, use `applyScaledFont(size:weight:relativeTo:)`.
- **`label.font = .preferredFont(forTextStyle: .headline)` without setting `adjustsFontForContentSizeCategory = true`.** Fix: replace with `applyTextStyle(.headline)`.
- **`UIBarButtonItem(image: UIImage(systemName: …), …)`** without setting `accessibilityLabel`. Fix: use `UIBarButtonItem(symbolName:accessibilityLabel:target:action:)`.
- **`UIImageView()` with semantic content and no explicit `isAccessibilityElement` decision.** Fix: set it to `true` with a label, or `false` for decorative.
- **`numberOfLines = 1` on a label whose text is dynamic content from a server, user input, or localized copy**, without verification at AX5. Fix: either set to `0`, or document why `1` is safe (fixed-width chip, server-side max length, etc.).
- **Animations that ignore `UIAccessibility.isReduceMotionEnabled`.** Fix: branch on the flag and skip the animation.
- **`UIImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14)`** for an icon next to text. Fix: use `UIImage.SymbolConfiguration(textStyle: <matching style>)` so the icon scales with the text.
- **`accessibilityLabel = "Logout"`** (hard-coded English string). Fix: route through `<Module>Strings.<key>` exactly like every other user-facing string.

## Not a violation (false positives to avoid)

- **Custom-size font wrapped in `UIFontMetrics`** — that's the documented escape hatch (rule 3 under Dynamic Type). The only existing case is `PokemonDetailViewController.makeTypeBadge`, and it is correct.
- **Decorative `UIImageView` next to a label that already names the content** with `isAccessibilityElement = false` — that's the correct, intentional way to silence VoiceOver duplication.
- **`UIButton.Configuration`-based button that sets `outgoing.font` inside `titleTextAttributesTransformer`** — the only correct place to set the font in that flow; the `applyTextStyle` helper does not apply.
- **`NSAttributedString` carrying a `.font` attribute** — that's the right place to set the font on attributed copy.

## Where this skill sits

- Typography helpers live in `SharedUI/Sources/Extensions/` alongside `UIView+AutoLayout.swift`.
- Localized accessibility copy follows the same `<Module>Strings.<key>` workflow as any other user-facing string (see `shared-ui-reuse` skill, "Localized strings in UIKit code").
- Color tokens used in manual contrast overrides come from `SharedUIAsset` (see `shared-ui-reuse` skill, "Color tokens").

## Non-goals

This skill does not cover:

- General SharedUI reuse, layout helpers, or card style — see `shared-ui-reuse`.
- Localized string mechanics or `.strings` vs `.xcstrings` — see `CLAUDE.md` and `shared-ui-reuse`.
- Concurrency annotations on UIKit types — see `swift-concurrency`.
- Asset access — see `CLAUDE.md` → "Code conventions".
