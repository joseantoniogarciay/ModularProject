---
name: launch-screen-asset-sync
description: Enforce the App↔SharedUI asset duplication invariant whenever the user edits the UILaunchScreen dictionary in App/Project.swift, or modifies the Background colorset / Logo imageset under App/Resources/Assets.xcassets or SharedUI/Resources/Assets.xcassets. iOS's UILaunchScreen Info.plist only reads from the main app bundle, so these assets must live in App, and the SharedUI copies must stay byte-for-byte equivalent so SharedUIAsset.background and SharedUIAsset.logo work at runtime.
---

# Launch screen ↔ SharedUI asset sync

## The invariant

The launch screen references two assets that require duplication between `App` (so iOS can resolve them at cold start) and `SharedUI` (so runtime UI code can read them via the Tuist-synthesized `SharedUIAsset` accessor):

| Asset | Copy in App (launch screen) | Copy in SharedUI (runtime use) | Runtime accessor |
|---|---|---|---|
| Background (Color Set) | `App/Resources/Assets.xcassets/Background.colorset/` | `SharedUI/Resources/Assets.xcassets/Background.colorset/` | `SharedUIAsset.background.color` |
| Logo (Image Set) | `App/Resources/Assets.xcassets/Logo.imageset/` | `SharedUI/Resources/Assets.xcassets/Logo.imageset/` | `SharedUIAsset.logo.image` |

**Why two copies**: iOS resolves `UILaunchScreen.UIColorName` and `UILaunchScreen.UIImageName` from the main app bundle only. Framework bundles are not visible to the launch-screen system. Without the App-side copy, the splash renders with the default system background / no logo. Without the SharedUI-side copy, `SharedUIAsset.background` / `SharedUIAsset.logo` are unavailable to features and shared UI.

**Core has no asset catalog**: `Core/Resources/` contains only the `.lproj` string tables. Do not add `Core/Resources/Assets.xcassets/` — runtime asset access is owned by `SharedUI`, and Core must remain UI-free.

**Consequence**: a change to Background or Logo in one copy without the matching change to the other produces a silent visual mismatch between cold-start splash and the rest of the app.

## Trigger this skill when

Any of these are being edited:

- `App/Project.swift` — specifically the `UILaunchScreen` dictionary (`UIColorName`, `UIImageName`, or related keys).
- `App/Resources/Assets.xcassets/Background.colorset/Contents.json` or `SharedUI/Resources/Assets.xcassets/Background.colorset/Contents.json`.
- `App/Resources/Assets.xcassets/Logo.imageset/` or `SharedUI/Resources/Assets.xcassets/Logo.imageset/` (any file inside, including the PNGs).
- A new asset is being added that the launch screen will reference (check whether a SharedUI copy is also needed before creating one).

## Verification checklist

Before reporting the task as complete:

1. **Background parity**: `App/Resources/Assets.xcassets/Background.colorset/` and `SharedUI/Resources/Assets.xcassets/Background.colorset/` are byte-for-byte equivalent (use `diff -r`).
2. **Logo parity**: `App/Resources/Assets.xcassets/Logo.imageset/` and `SharedUI/Resources/Assets.xcassets/Logo.imageset/` are byte-for-byte equivalent — `Contents.json` AND every `.png` variant (`@1x`, `@2x`, `@3x`, light + dark).
3. **No Core asset catalog**: `Core/Resources/Assets.xcassets/` must not exist.
4. **`tuist generate`** ran after any manifest or resource-folder change so `SharedUI/Derived/Sources/TuistAssets+SharedUI.swift` is up to date.
5. **Build succeeds**: `xcodebuild -workspace ModularProject.xcworkspace -scheme App -destination 'generic/platform=iOS Simulator' build` is green.
6. **Asset-catalog warnings**: scan build output for `warning: ... is not present in any asset catalogs` — indicates a missing or renamed asset.

## How to detect desync quickly

```bash
diff -r App/Resources/Assets.xcassets/Background.colorset SharedUI/Resources/Assets.xcassets/Background.colorset
diff -r App/Resources/Assets.xcassets/Logo.imageset       SharedUI/Resources/Assets.xcassets/Logo.imageset
```

Empty output (exit 0) means the duplication is consistent. Any output is a desync that must be resolved before completing the task.

## How to fix desync

Treat **SharedUI as the source of truth** for these assets — that is where the runtime consumers live and where the Tuist-synthesized accessor reads. If a discrepancy is found:

1. Apply the intended change to `SharedUI/Resources/Assets.xcassets/<Asset>/`.
2. Mirror the same change byte-for-byte to `App/Resources/Assets.xcassets/<Asset>/`. For image sets, copy every PNG variant, not just `Contents.json`.
3. Regenerate with `tuist generate` and build.

## Edge cases

- **Adding a new launch-screen asset**: check first whether any runtime code will consume it. If yes, create it in both App and SharedUI. If no, keep it App-only.
- **Removing a launch-screen asset**: if `UILaunchScreen` stops referencing an asset, the App copy can be deleted. The SharedUI copy stays only if it is still consumed elsewhere (via `SharedUIAsset.<name>`).
- **Pure App-only assets** (`AppIcon.appiconset`, `AccentColor.colorset`): these do **not** participate in the duplication invariant.
- **Pure SharedUI-only assets** (assets that the launch screen never references — most of the palette: `Accent`, `Text`, `SecondaryText`, `CardBackground`, `BannerErrorBackground`, `StatTrack`, …): the skill does not apply. These live only in `SharedUI/Resources/Assets.xcassets/`.

## Where the duplication invariant is documented

See the `Modular architecture` section of `CLAUDE.md` and the dependency rules. The launch-screen asset duplication is an exception to the "single source of truth" principle, justified by the iOS launch-screen bundle-resolution limitation described above.
