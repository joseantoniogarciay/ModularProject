---
name: ui-testing-conventions
description: Apply when adding UI tests to the App target, deciding what deserves a UI test vs a unit test, or extending the --uitesting stub infrastructure. Covers two modes: fake-network accessibility audits (performAccessibilityAudit) and real-network use-case / flow tests. Includes the XCUIApplication + nonisolated(unsafe) + MainActor.assumeIsolated Swift 6 concurrency setup.
---

# UI testing conventions

UI tests run against a live app process on a simulator. They are the right layer for:

- **Full-screen accessibility audits** — contrast, VoiceOver order, hit regions, Dynamic Type, element descriptions across all elements at once.
- **End-to-end user flows** — login, sign-up, add-to-cart; things that need real navigation and coordinator glue that unit tests cannot exercise.

They are **not** the right layer for component contracts (height constraints, `adjustsFontForContentSizeCategory`, state transitions). Those belong in unit tests. See the `unit-testing-conventions` skill.

---

## Two modes of UI tests in this project

| Mode | Network | Location | When to write |
|---|---|---|---|
| Accessibility audit | Fake (`--uitesting` stubs) | `App/UITests/Accessibility/` | Every screen, once per screen state (loaded, error, empty) |
| Use-case / flow | Real (live backend) or recorded | `App/UITests/Flows/` | Critical happy paths that span multiple screens; login, checkout, onboarding |

---

## Target configuration

### UI test targets in `App/Project.swift`

There are two UI test targets — one per app variant — sharing the same `UITests/` source folder:

```swift
// Runs against the production App binary.
.target(
    name: "AppUITests",
    destinations: .iOS,
    product: .uiTests,
    bundleId: "com.modular.app.uitests",
    deploymentTargets: .iOS("17.0"),
    buildableFolders: ["UITests"],         // Xcode 16 synchronized root groups
    dependencies: [.target(name: "App")],
    settings: Settings.modularUITests(targetName: "App")
),
// Same UITests/ folder — compiled against AppDev.
// DEV flag mirrors the host so #if DEV guards resolve correctly.
.target(
    name: "AppDevUITests",
    destinations: .iOS,
    product: .uiTests,
    bundleId: "com.modular.app.devuitests",
    deploymentTargets: .iOS("17.0"),
    buildableFolders: ["UITests"],
    dependencies: [.target(name: "AppDev")],
    settings: Settings.modularUITests(targetName: "AppDev", addingConditions: "DEV")
),
```

`buildableFolders` means **adding new `.swift` files under `App/UITests/` does NOT require `tuist generate`**. Both targets pick up the same files automatically.

Each variant's scheme runs its own UI test target:

```swift
.scheme(
    name: "App",
    buildAction: .buildAction(targets: [.target("App")]),
    testAction: .targets([
        .testableTarget(target: .target("AppTests")),
        .testableTarget(target: .target("AppUITests")),
    ])
),
.scheme(
    name: "AppDev",
    buildAction: .buildAction(targets: [.target("AppDev")]),
    testAction: .targets([
        .testableTarget(target: .target("AppDevTests")),
        .testableTarget(target: .target("AppDevUITests")),
    ])
),
```

### `Settings.modularUITests(targetName:addingConditions:)` — what it does

```swift
// Tuist/ProjectDescriptionHelpers/Module.swift
public static func modularUITests(targetName: String, addingConditions conditions: String = "") -> Settings {
    var base = modularBaseSettings
    base["SWIFT_TREAT_WARNINGS_AS_ERRORS"] = "YES"
    base["TEST_TARGET_NAME"] = .string(targetName)
    if !conditions.isEmpty {
        base["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "$(inherited) \(conditions)"
    }
    return .settings(base: base)
}
```

`TEST_TARGET_NAME` links the UI test bundle to the host app. `SWIFT_TREAT_WARNINGS_AS_ERRORS` catches concurrency warnings before they become merge-time surprises. Pass `addingConditions: "DEV"` when targeting `AppDev` so `#if DEV` guards in test files resolve correctly against the host variant's flags.

**Why code signing is not disabled here** (unlike `modularTests`): UI test runners are separate processes that Xcode must launch and attach its debugger to. This requires at least ad-hoc signing on the runner bundle. Xcode automatically uses `-` (ad-hoc) for simulator debug builds — disabling signing (`CODE_SIGN_IDENTITY = ""` / `CODE_SIGNING_ALLOWED = NO`) would break Cmd+U in Xcode with a "Could not attach to pid" error. Unit tests don't have this problem because the test bundle is *loaded into* the host app process, not launched separately.

For CI, pass `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO` on the `xcodebuild` command line — those override the project setting and suppress signing in the automated build environment.

---

## Swift 6 concurrency setup for `XCUIApplication`

`XCUIApplication` is `@MainActor`. `setUp` and `tearDown` are `nonisolated` in `XCTestCase`. The pattern that satisfies Swift 6 strict concurrency is:

1. **No `@MainActor` on the test class** — conflicts with nonisolated `setUp`/`tearDown`.
2. **`nonisolated(unsafe)` on `app`** with a documented invariant.
3. **`MainActor.assumeIsolated` in `setUp`** using a local variable (not `self.app`) to avoid "sending self risks causing data races" in Swift 6.2.
4. **Local variable capture in `tearDown`** for the same reason.
5. **`@MainActor` on every test method** that queries `app`.

```swift
// App/UITests/Accessibility/PokemonListAccessibilityTests.swift

final class PokemonListAccessibilityTests: XCTestCase {

    // Invariant: accessed exclusively from @MainActor test methods and from
    // setUp/tearDown which XCTest guarantees run on the main thread.
    // Removal plan: remove nonisolated(unsafe) + assumeIsolated once XCTest
    // annotates setUp/tearDown as @MainActor in a future SDK release.
    nonisolated(unsafe) var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        let application = MainActor.assumeIsolated {
            let a = XCUIApplication()
            a.launchArguments = ["--uitesting"]   // activates AppDependencies.uitesting()
            a.launch()
            return a
        }
        app = application   // assign outside closure — no self capture inside
    }

    override func tearDown() {
        let application = app   // local var — do NOT capture self inside the closure
        MainActor.assumeIsolated { application?.terminate() }
        app = nil
        super.tearDown()
    }

    @MainActor
    func testPokemonListPassesAccessibilityAudit() throws {
        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 3), "Pokémon list table must appear")
        try app.performAccessibilityAudit()
    }
}
```

---

## Mode 1 — Fake-network accessibility audits

### How the fake network works

Launching with `--uitesting` makes `SceneDelegate` call `AppDependencies.uitesting()` instead of `AppDependencies.live()`. The detection lives in `App/Sources/SceneDelegate.swift`:

```swift
// SceneDelegate.swift (inside scene(_:willConnectTo:options:))
#if DEBUG
let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")
let dependencies = isUITesting ? AppDependencies.uitesting() : AppDependencies.live()
#else
let dependencies = AppDependencies.live()
#endif
```

The stubs live in `App/Sources/AppDependencies+UITesting.swift` (compiled only under `#if DEBUG`):

```swift
extension AppDependencies {
    static func uitesting() -> AppDependencies {
        AppDependencies(
            pokemonRepository: PreviewPokemonRepository(),
            imageLoader: PreviewImageLoader(),
            authSession: UITestAuthSession(),
            cartRepository: UITestCartRepository(),
            productsRepository: UITestProductsRepository(),
            themeStore: UserDefaultsThemeStore()
        )
    }
}
```

Stubs return data synchronously (or near-instantly). Tests run in ~5 s, no server required.

### Adding a stub for a new repository

When a new repository protocol is added to `AppDependencies`:

1. Create a minimal implementation in `AppDependencies+UITesting.swift` that returns empty/fixture data.
2. Use `@MainActor` if and only if the protocol is `@MainActor`-isolated; otherwise a plain `struct` with `@unchecked Sendable` is fine (see the unit-testing-conventions mock patterns).
3. Wire it in `AppDependencies.uitesting()`.
4. Do NOT use the same struct as the SwiftUI preview stub if they have different needs — duplication is fine here.

### Writing the audit test

```swift
// App/UITests/Accessibility/<ScreenName>AccessibilityTests.swift

@MainActor
func testScreenNamePassesAccessibilityAudit() throws {
    // 1. Wait for the screen element that proves loading finished.
    let table = app.tables.firstMatch
    XCTAssertTrue(table.waitForExistence(timeout: 3), "<ScreenName> must appear")

    // 2. Full audit — contrast, VoiceOver, hit regions, Dynamic Type, descriptions.
    try app.performAccessibilityAudit()
}
```

**One test per screen state** (loaded, error, empty). Navigate to error/empty states via launch arguments or accessibility identifiers (`app.buttons["retry"].tap()`).

### `issueHandler` — when and how to suppress

`performAccessibilityAudit()` fails the test on the first violation. Use `issueHandler` only when:
- A platform bug causes a false positive (document the radar number).
- A violation is genuinely deferred with a tracked ticket.

**Never suppress without explanation.** Include a `// TODO:` naming the file, property, and fix:

```swift
try app.performAccessibilityAudit { issue in
    // TODO: Fix PokemonCell nameLabel clipping — remove once layout is updated.
    // Tracked: GH-#42
    issue.auditType == .textClipped
}
```

Returning `true` from the handler silences that violation type for the whole audit. Be as specific as possible (check `issue.element` if needed) to avoid masking unrelated regressions.

If you can fix the violation instead of suppressing it, do so. The `issueHandler` is not a workaround bin.

### Adding a new screen audit

1. Create `App/UITests/Accessibility/<ScreenName>AccessibilityTests.swift`.
2. Copy the concurrency boilerplate (`nonisolated(unsafe) var app`, `setUp`/`tearDown`).
3. Set `launchArguments = ["--uitesting"]`.
4. Add one `testXxxPassesAccessibilityAudit()` per screen state.
5. `tuist generate` is NOT required — `buildableFolders` picks up the new file automatically.

---

## Mode 2 — Real-network use-case / flow tests

### When to write

Write a flow test when:
- The flow spans multiple screens (login → home, onboarding → tab bar).
- A regression in navigation or coordinator glue would not be caught by unit tests.
- The feature has a clear, stable happy path that runs in < 30 s on the simulator.

Do **not** write flow tests for every permutation — they are expensive and fragile. One test per critical path is enough.

### Structure

```
App/UITests/Flows/
├── LoginFlowTests.swift
├── SignUpFlowTests.swift
└── CheckoutFlowTests.swift
```

Flow tests do NOT use `--uitesting`. They connect to the real backend (or a local mock server for CI). They do not inherit `AppDependencies.uitesting()`.

```swift
// App/UITests/Flows/LoginFlowTests.swift

final class LoginFlowTests: XCTestCase {

    nonisolated(unsafe) var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        let application = MainActor.assumeIsolated {
            let a = XCUIApplication()
            // No --uitesting here — real network (or point to a local mock server
            // via a different launch argument if needed).
            a.launch()
            return a
        }
        app = application
    }

    override func tearDown() {
        let application = app
        MainActor.assumeIsolated { application?.terminate() }
        app = nil
        super.tearDown()
    }

    @MainActor
    func testLoginHappyPath() {
        // Tap "Log in" on the welcome screen.
        app.buttons["Log in"].tap()

        // Fill credentials.
        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 3))
        emailField.tap()
        emailField.typeText("test@example.com")

        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText("password123")

        app.buttons["Continue"].tap()

        // Assert we land on the home tab bar.
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Home tab bar must appear after login")
    }
}
```

### Accessibility identifiers for robust element lookup

Prefer `accessibilityIdentifier` over label-based queries for interactive elements in flow tests — labels change with localization, identifiers do not:

```swift
// In the view controller:
emailTextField.accessibilityIdentifier = "login.email"

// In the test:
app.textFields["login.email"].tap()
```

Use `accessibilityLabel` queries only for elements where the label text itself is part of the contract being tested.

---

## Checklist before shipping a new UI test file

- [ ] Fake-network tests use `--uitesting` launch argument; flow tests do not.
- [ ] `nonisolated(unsafe) var app` has the documented invariant and removal plan comment.
- [ ] `setUp` assigns to `app` outside the `assumeIsolated` closure (local variable inside, `app = local` outside).
- [ ] `tearDown` captures `app` into a local before the closure.
- [ ] Every test method is `@MainActor`.
- [ ] `continueAfterFailure = false` is set in `setUp`.
- [ ] Accessibility audit tests cover each meaningful screen state.
- [ ] No `issueHandler` suppressions without a `// TODO:` naming the file, property, and fix.
- [ ] Build passes: `xcodebuild -workspace ModularProject.xcworkspace -scheme App -destination '...' test`.
