---
name: launch-screen-asset-sync
description: Enforce the App↔Core asset duplication invariant whenever the user edits the UILaunchScreen dictionary in App/Project.swift, or modifies the Background colorset under App/Resources/Assets.xcassets or Core/Resources/Assets.xcassets. iOS's UILaunchScreen Info.plist only reads from the main app bundle, so the Background color must live in App, and the Core copy must stay byte-for-byte equivalent so CoreAsset.background works at runtime.
---

# Launch screen ↔ Core asset sync

## The invariant

The launch screen references one asset that requires duplication:

| Asset | Copy in App (launch screen only) | Copy in Core (runtime use) |
|---|---|---|
| Background (Color Set) | `App/Resources/Assets.xcassets/Background.colorset/` | `Core/Resources/Assets.xcassets/Background.colorset/` |

**Why two copies**: iOS resolves `UILaunchScreen.UIColorName` from the main app bundle only. Framework bundles are not visible to the launch-screen system. Without the App-side copy, the splash renders with the default system background. Without the Core-side copy, `CoreAsset.background` is unavailable to features and shared UI.

**Logo is App-only**: `UILaunchScreen.UIImageName` references `Logo`, which lives only in `App/Resources/Assets.xcassets/Logo.imageset/`. There is no Core copy — `CoreAsset.logo` does not exist and should not be added unless a runtime consumer actually requires it.

**Consequence**: a change to Background in one copy without the matching change to the other produces a silent visual mismatch between cold-start splash and the rest of the app.

## Trigger this skill when

Any of these are being edited:

- `App/Project.swift` — specifically the `UILaunchScreen` dictionary (`UIColorName`, `UIImageName`, or related keys).
- `App/Resources/Assets.xcassets/Background.colorset/Contents.json`.
- `Core/Resources/Assets.xcassets/Background.colorset/Contents.json`.
- `App/Resources/Assets.xcassets/Logo.imageset/` — App-only, no sync needed.
- A new asset is being added that the launch screen will reference (check whether a Core copy is also needed before creating one).

## Verification checklist

Before reporting the task as complete:

1. **Background parity**: `App/Resources/Assets.xcassets/Background.colorset/Contents.json` and `Core/Resources/Assets.xcassets/Background.colorset/Contents.json` are byte-for-byte equivalent.
2. **Logo is App-only**: `Core/Resources/Assets.xcassets/Logo.imageset/` must not exist.
3. **`tuist generate`** ran after any manifest or resource-folder change so `Core/Derived/Sources/TuistAssets+Core.swift` is up to date.
4. **Build succeeds**: `xcodebuild -workspace ModularProject.xcworkspace -scheme App -destination 'generic/platform=iOS Simulator' build` is green.
5. **Asset-catalog warnings**: scan build output for `warning: ... is not present in any asset catalogs` — indicates a missing or renamed asset.

## How to detect desync quickly

```bash
diff -r App/Resources/Assets.xcassets/Background.colorset Core/Resources/Assets.xcassets/Background.colorset
```

Empty output means the duplication is consistent. Any output is a desync that must be resolved before completing the task.

## How to fix desync

Treat **Core as the source of truth** for the Background color. If a discrepancy is found:

1. Apply the intended change to `Core/Resources/Assets.xcassets/Background.colorset/Contents.json`.
2. Mirror the same change byte-for-byte to `App/Resources/Assets.xcassets/Background.colorset/Contents.json`.
3. Regenerate with `tuist generate` and build.

## Edge cases

- **Adding a new launch-screen asset**: check first whether any runtime code will consume it. If yes, create it in both App and Core. If no (like Logo), keep it App-only.
- **Removing a launch-screen asset**: if `UILaunchScreen` stops referencing an asset, the App copy can be deleted. The Core copy stays only if it is still consumed elsewhere.
- **Pure App-only assets** (`AppIcon.appiconset`, `Logo.imageset`, `AccentColor.colorset`): these do **not** participate in the duplication invariant.
- **Pure Core-only assets** (assets that the launch screen never references): the skill does not apply.

## Where the duplication invariant is documented

See the `Modular architecture` section of `CLAUDE.md` and the dependency rules. The launch-screen asset duplication is an exception to the "single source of truth" principle, justified by the iOS launch-screen bundle-resolution limitation described above.
