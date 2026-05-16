---
name: launch-screen-asset-sync
description: Enforce the App↔Core asset duplication invariant whenever the user edits the UILaunchScreen dictionary in App/Project.swift, modifies any colorset/imageset under App/Resources/Assets.xcassets that the launch screen references (Background, Logo), or modifies the matching colorset/imageset under Core/Resources/Assets.xcassets. iOS's UILaunchScreen Info.plist only reads from the main app bundle, so launch-screen assets must live in App, but runtime code uses the Core copies — both copies must stay byte-for-byte equivalent.
---

# Launch screen ↔ Core asset sync

## The invariant

This project deliberately keeps two copies of every asset that the launch screen references:

| Asset | Copy in App (launch screen only) | Copy in Core (runtime use) |
|---|---|---|
| Background (Color Set) | `App/Resources/Assets.xcassets/Background.colorset/` | `Core/Resources/Assets.xcassets/Background.colorset/` |
| Logo (Image Set) | `App/Resources/Assets.xcassets/Logo.imageset/` | `Core/Resources/Assets.xcassets/Logo.imageset/` |

**Why two copies**: iOS resolves `UILaunchScreen.UIColorName` and `UILaunchScreen.UIImageName` from the main app bundle only. Framework bundles are not visible to the launch-screen system. Without the App-side copy, the splash renders with default system colors. Without the Core-side copy, App and Features cannot share a single typed accessor (`CoreAsset.background`, `CoreAsset.logo`).

**Consequence**: a change to one copy without the matching change to the other produces a silent visual mismatch between cold-start splash and the rest of the app.

## Trigger this skill when

Any of these are being edited:

- `App/Project.swift` — specifically the `UILaunchScreen` dictionary (`UIColorName`, `UIImageName`, or related keys).
- `App/Resources/Assets.xcassets/Background.colorset/Contents.json` or its image files.
- `App/Resources/Assets.xcassets/Logo.imageset/Contents.json` or its image files.
- `Core/Resources/Assets.xcassets/Background.colorset/...`
- `Core/Resources/Assets.xcassets/Logo.imageset/...`
- A new asset is being added that the launch screen will reference (then the duplication invariant extends to that new asset too).

## Verification checklist

Before reporting the task as complete:

1. **Asset name parity**: every colorset/imageset name referenced from `UILaunchScreen` exists in both `App/Resources/Assets.xcassets/` and `Core/Resources/Assets.xcassets/`.
2. **Contents parity**: the `Contents.json` of each duplicated asset is byte-for-byte equivalent between App and Core. Same color components, same appearance variants, same image filenames, same scales.
3. **Image file parity**: any PNG/PDF inside an `*.imageset/` exists in both App and Core copies with identical bytes (or is intentionally absent from both — placeholders are fine as long as both are placeholders).
4. **`tuist generate`** ran after the change, so `Core/Derived/Sources/TuistAssets+Core.swift` reflects the new state.
5. **Build succeeds**: `xcodebuild -workspace ModularProject.xcworkspace -scheme App -destination 'generic/platform=iOS Simulator' build` is green.
6. **Asset-catalog warnings**: scan build output for `warning: ... is not present in any asset catalogs` or `error: ... contained a matching ... set` — both can indicate a missing or renamed asset.

## How to detect desync quickly

```bash
diff -r App/Resources/Assets.xcassets/Background.colorset Core/Resources/Assets.xcassets/Background.colorset
diff -r App/Resources/Assets.xcassets/Logo.imageset       Core/Resources/Assets.xcassets/Logo.imageset
```

Empty output means the duplication is consistent. Any output is a desync that must be resolved before completing the task.

## How to fix desync

Treat **Core as the source of truth** for runtime values. If a discrepancy is found:

1. Apply the intended change to `Core/Resources/Assets.xcassets/<asset>/`.
2. Mirror the same change byte-for-byte to `App/Resources/Assets.xcassets/<asset>/`.
3. If a new asset name is being introduced for the launch screen, add it to **both** catalogs in the same commit.
4. Regenerate with `tuist generate` and build.

## Edge cases

- **Adding a new launch-screen asset**: requires creating it in App (so `UILaunchScreen` can find it) AND in Core (so `CoreAsset.<name>` is usable elsewhere). The skill applies.
- **Removing a launch-screen asset**: if `UILaunchScreen` stops referencing an asset, the App copy can be deleted. The Core copy stays only if it is still consumed elsewhere — otherwise it should also be removed to avoid dead resources.
- **Pure App-only assets** (e.g. `AppIcon.appiconset`, `AccentColor.colorset`): these do **not** participate in the duplication invariant. They live only in App. The skill does not apply to changes that touch only those.
- **Pure Core-only assets** (assets that the launch screen never references): the skill does not apply.

## Where the duplication invariant is documented

See the `Modular architecture` section of `CLAUDE.md` and the dependency rules. The launch-screen asset duplication is an exception to the "single source of truth" principle, justified by the iOS launch-screen bundle-resolution limitation described above.
