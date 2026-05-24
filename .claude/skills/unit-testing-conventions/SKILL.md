---
name: unit-testing-conventions
description: Apply when adding unit tests to any module, deciding what deserves a test, or setting up a new test target. Covers what has real value (pure logic, decoders, state machines), what does not (DTOs, ViewControllers, Coordinators), how to wire a Tuist test target, Swift 6 mock patterns for Sendable protocols, and the XCTest + @MainActor concurrency setup that was learned building AuthSessionImplTests.
---

# Unit testing conventions

UI tests are a separate concern. This skill covers **unit tests only**.

---

## What is worth testing

Test code that contains **logic** — branching, mapping, accumulation, state transitions — independently of the UI. The key question is: "if this breaks silently, would a failing test catch it before a user does?"

### High value — test these

| Target | Why |
|---|---|
| Pure utility functions (`JWTExpiry`, `TextFieldValidators`) | No dependencies, deterministic, many edge cases, silent failures have real consequences |
| Resilience decoders (`FailableDecodable`, `FailableDecodableArray`) | The whole point is to not throw on bad data; easy to regress without a test |
| State machines (`AuthSessionImpl`) | Multiple branches, error mappings, side effects (token persistence); a bug here affects every screen |
| Error mapping in orchestrators | When a facade chains multiple repo calls and maps errors (e.g. `register → login → autoLoginFailed`), test each mapping path |

### Low value — skip these

| Target | Why |
|---|---|
| `Decodable`/`Encodable` DTOs | Trivial struct synthesis, no logic; a real API response in an integration test catches mistakes here |
| `*RepositoryImpl` | Thin transport wrappers; logic is in the error mapping (which belongs in the orchestrator test anyway) |
| `ViewControllers` and `Coordinators` | Navigation glue with UIKit dependencies; UI tests cover this better and with more confidence |
| `Project.swift` or Tuist manifests | No logic |

---

## Adding a test target

### Framework modules (Core, SharedUI, Data, Features/*)

Use the `testDependencies` parameter added to `Project.framework`:

```swift
// Core/Project.swift
let project = Project.framework(
    name: "Core",
    resources: ["Resources/**"],
    testDependencies: []          // [] = no extra deps beyond Core itself
)
```

This generates a `<Name>Tests` target with:
- `product: .unitTests`
- `bundleId: "com.modular.app.<name>tests"`
- `deploymentTargets: .iOS("17.0")`
- `buildableFolders: ["Tests"]`   ← Xcode 16 synchronized root groups, no tuist generate needed for new files
- `settings: Settings.modularTests`

Create the test files at `<Module>/Tests/*.swift`. Run `tuist generate` once to register the target; subsequent file additions are picked up automatically.

### App target (manual, App/Project.swift)

App is not a framework so the helper doesn't apply. Add the target manually:

```swift
.target(
    name: "AppTests",
    destinations: .iOS,
    product: .unitTests,
    bundleId: "com.modular.app.tests",
    deploymentTargets: .iOS("17.0"),
    buildableFolders: ["Tests"],
    dependencies: [
        .target(name: "App"),
        .project(target: "Core", path: "../Core"),
    ],
    settings: Settings.modularTests
),
```

Test files live at `App/Tests/*.swift`. Use `@testable import App` to access internal types.

### `Settings.modularTests` — what it does

```swift
// Tuist/ProjectDescriptionHelpers/Module.swift
public static let modularTests: Settings = {
    var base = modularBaseSettings
    base["CODE_SIGN_IDENTITY"] = ""
    base["CODE_SIGNING_REQUIRED"] = "NO"
    base["CODE_SIGNING_ALLOWED"] = "NO"
    base["SWIFT_TREAT_WARNINGS_AS_ERRORS"] = "YES"   // ← critical
    return .settings(base: base)
}()
```

`SWIFT_TREAT_WARNINGS_AS_ERRORS` is **only** on test targets because:
- In production targets Xcode surfaces warnings in the editor naturally.
- In test targets the compiler suppresses them by default — they go completely unnoticed unless they are promoted to errors.
- This is what caught the `var fields` → `let fields` mistake and all the `@MainActor` concurrency warnings in `AuthSessionImplTests`.

---

## Mock patterns for Swift 6 + Sendable protocols

The project's repository protocols all extend `Sendable`:

```swift
public protocol TokenStore: Sendable {
    func load() async -> AuthTokens?
    func save(_ tokens: AuthTokens) async
    func clear() async
}
```

**Use `@unchecked Sendable` on mock classes** with a documented invariant. Do NOT use `@MainActor` on mocks — it causes "main actor-isolated property cannot be accessed from outside of the actor" errors because the protocol methods are nonisolated and the compiler must satisfy them as nonisolated witnesses.

```swift
// ✅ Correct mock pattern for this project
/// Thread safety invariant: accessed exclusively from @MainActor test methods
/// and from setUp/tearDown which XCTest guarantees run on the main thread.
/// Remove @unchecked Sendable if a mock framework is adopted later.
final class MockTokenStore: TokenStore, @unchecked Sendable {
    var stubbedTokens: AuthTokens?
    var savedTokens: AuthTokens?
    var clearCallCount = 0

    func load() async -> AuthTokens? { stubbedTokens }
    func save(_ tokens: AuthTokens) async { savedTokens = tokens }
    func clear() async { clearCallCount += 1; stubbedTokens = nil }
}
```

```swift
// ❌ @MainActor on the mock — produces compiler errors
@MainActor
final class MockTokenStore: TokenStore {
    // error: main actor-isolated property 'stubbedTokens' cannot be
    // accessed from outside of the actor
    func load() async -> AuthTokens? { stubbedTokens }
}
```

For typed-throws protocols:

```swift
final class MockAccessRepository: AccessRepository, @unchecked Sendable {
    var stubbedLoginResult: LoginResult = .fixture()
    var stubbedLoginError: LoginError?

    func login(identifier: String, password: String) async throws(LoginError) -> LoginResult {
        if let error = stubbedLoginError { throw error }
        return stubbedLoginResult
    }
}
```

---

## XCTest + `@MainActor` — the correct setup

Testing `@MainActor` types like `AuthSessionImpl` requires careful structuring to satisfy Swift 6.2's region-based isolation checks (Xcode 26).

### The problem with `@MainActor` on the test class

Marking the test class `@MainActor` causes `setUp` and `tearDown` to conflict with their nonisolated base declarations in `XCTestCase`:

```swift
// ❌ Produces warnings even with SWIFT_APPROACHABLE_CONCURRENCY
@MainActor
final class MyTests: XCTestCase {
    var sut: SomeSUT!

    override func setUp() {
        sut = SomeSUT()   // error: main actor-isolated property can not be
    }                     // mutated from a nonisolated context
}
```

### The correct setup

1. **No `@MainActor` on the test class**.
2. **`nonisolated(unsafe)` on the properties** that hold `@MainActor` types or mocks.
3. **`@MainActor` on every individual test method** that accesses `@MainActor` code.
4. **`MainActor.assumeIsolated`** in `setUp` to call `@MainActor` initialisers — XCTest guarantees setUp runs on the main thread.
5. **Local variables** in `setUp` to avoid capturing `self` in the `assumeIsolated` closure (Swift 6.2 "sending self" diagnostic).

```swift
final class AuthSessionImplTests: XCTestCase {

    // Invariant: accessed exclusively from @MainActor test methods and from
    // setUp/tearDown which XCTest guarantees run on the main thread.
    // Removal plan: remove nonisolated(unsafe) once XCTest annotates
    // setUp/tearDown as @MainActor in a future SDK release.
    nonisolated(unsafe) var tokenStore: MockTokenStore!
    nonisolated(unsafe) var accessRepository: MockAccessRepository!
    nonisolated(unsafe) var userRepository: MockUserRepository!
    nonisolated(unsafe) var sut: AuthSessionImpl!

    override func setUp() {
        super.setUp()
        // Build mocks as LOCAL VARIABLES — not as self.x — so that the
        // assumeIsolated closure below does not capture `self`. Capturing self
        // in a @MainActor closure from a nonisolated method triggers the Swift
        // 6.2 "sending self risks causing data races" diagnostic.
        let store = MockTokenStore()
        let access = MockAccessRepository()
        let userRepo = MockUserRepository()
        let session = MainActor.assumeIsolated {
            // Safe: XCTest calls setUp on the main thread (main actor's executor).
            AuthSessionImpl(tokenStore: store, accessRepository: access, userRepository: userRepo)
        }
        tokenStore = store
        accessRepository = access
        userRepository = userRepo
        sut = session
    }

    override func tearDown() {
        sut = nil           // nonisolated(unsafe) var — no @MainActor needed
        super.tearDown()
    }

    // Every test method that reads @MainActor state must be @MainActor.
    @MainActor
    func testSomething() async {
        await sut.restore()
        // sut.authState is @MainActor — direct access ok from @MainActor method
        guard case .anonymous = sut.authState else { ... }
    }
}
```

### Why local variables in setUp

```swift
// ❌ Captures self → Swift 6.2 error: "sending 'self' risks causing data races"
MainActor.assumeIsolated {
    sut = AuthSessionImpl(tokenStore: tokenStore, ...)  // self.sut, self.tokenStore
}

// ✅ Only local (@unchecked Sendable) vars in the closure — no self capture
let store = MockTokenStore()
let session = MainActor.assumeIsolated {
    AuthSessionImpl(tokenStore: store, ...)
}
sut = session
```

The mock's `@unchecked Sendable` conformance makes them safe to pass into the main-actor closure. `AuthSessionImpl` is `@MainActor`-isolated (and thus implicitly `Sendable` in Swift 6), so it can be returned from the closure and stored.

---

## Running tests from the command line

```bash
DEST='platform=iOS Simulator,id=<simulator-udid>'

# List available simulators
xcrun simctl list devices available

# Build and run a specific test scheme
xcodebuild \
  -workspace ModularProject.xcworkspace \
  -scheme Core \                  # or SharedUITests, App
  -destination "$DEST" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  test
```

Schemes with test targets in this project: `Core` (→ CoreTests), `SharedUITests`, `App` (→ AppTests).

---

---

## Accessibility testing — which layer to use

### Decision guide

| What you want to verify | Where |
|---|---|
| Component contracts: height constraint, `adjustsFontForContentSizeCategory`, `numberOfLines = 0`, specific state behaviour (loading → `isAccessibilityElement`) | **Unit test** (`SharedUI/Tests/`) |
| Full screen audit: contrast, VoiceOver order, hit regions, Dynamic Type, element descriptions across all elements | **UI test** (`App/UITests/`) |

"Testing accessibility" does NOT mean verifying that `accessibilityLabel` is non-empty on a button with a title — UIKit does that for free. Test the properties that are explicitly set in the code and can regress silently.

### Unit test pattern for UI components

Use a local `UIWindow` as the trait environment. No `setUp`/`tearDown` — one factory per test method to avoid shared state:

```swift
// SharedUI/Tests/Accessibility/PrimaryButtonAccessibilityTests.swift
final class PrimaryButtonAccessibilityTests: XCTestCase {

    @MainActor
    func testHeightMeetsMinimumHitRegion() {
        let (window, vc, button) = makeScene(title: "Continue")
        vc.view.layoutIfNeeded()
        _ = window   // keeps window alive for the duration of the test

        XCTAssertGreaterThanOrEqual(button.frame.height, 44)
    }

    @MainActor
    private func makeScene(title: String) -> (UIWindow, UIViewController, PrimaryButton) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.makeKeyAndVisible()
        let vc = UIViewController()
        window.rootViewController = vc
        let button = PrimaryButton()
        button.setTitle(title, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
            button.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 24),
            button.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -24),
        ])
        return (window, vc, button)
    }
}
```

Why local window and not `setUp`/`tearDown`: `UIWindow.init` is `@MainActor`, and `setUp`/`tearDown` are `nonisolated`, which forces `nonisolated(unsafe)` + `MainActor.assumeIsolated`. The local window pattern avoids all of that — each test is fully self-contained.

To simulate AX5: `vc.view.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge` before `layoutIfNeeded()`.

For checking Dynamic Type font: `label.font.fontDescriptor.object(forKey: .textStyle) != nil` proves the font was created with `preferredFont(forTextStyle:)` rather than `systemFont(ofSize:)`.

To filter button title labels (expected single-line): `UIView+Testing.swift` in the test target exposes `isInsideButton` and `findSubviews(ofType:)`.

### UI test pattern for full screen audit

```swift
// App/UITests/Accessibility/PokemonListAccessibilityTests.swift
final class PokemonListAccessibilityTests: XCTestCase {

    // Invariant: accessed exclusively from @MainActor test methods and setUp/tearDown
    // (XCTest guarantees main thread). Removal plan: remove once XCTest is @MainActor.
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
        app = application
    }

    override func tearDown() {
        let application = app   // local var — do NOT capture self in the closure
        MainActor.assumeIsolated { application?.terminate() }
        app = nil
        super.tearDown()
    }

    @MainActor
    func testPokemonListPassesAccessibilityAudit() throws {
        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 3))

        // Use issueHandler to exclude known issues with a TODO:
        try app.performAccessibilityAudit { issue in
            // TODO: Fix PokemonCell nameLabel clipping — remove once layout is updated.
            issue.auditType == .textClipped
        }
    }
}
```

The `--uitesting` launch argument activates `AppDependencies.uitesting()` in `SceneDelegate` (`#if DEBUG` guard). This swaps all network repositories for in-memory stubs (`PreviewPokemonRepository`, `UITestCartRepository`, etc.) so the tests run without a server and finish in ~5 s.

### Adding a new screen audit

1. Create `App/UITests/Accessibility/<ScreenName>AccessibilityTests.swift`.
2. Follow the pattern above (no new infrastructure needed — `tuist generate` is NOT required for new files under `UITests/`).
3. Add one `testXxxPassesAccessibilityAudit()` test per screen state (list loaded, error state, empty state if applicable).
4. If the audit finds violations, fix them. If a fix is deferred, add an `issueHandler` exclusion with a `// TODO:` that names the file, property, and fix needed. Never suppress without explanation.

---

## Checklist before shipping a new test file

- [ ] Tests exercise logic, not structure. If all assertions would pass even with a broken implementation, delete the test.
- [ ] No `@MainActor` on mock classes (see above).
- [ ] `nonisolated(unsafe)` properties have a documented invariant and removal plan.
- [ ] `setUp` uses local variables before `MainActor.assumeIsolated`, not `self.x`.
- [ ] Every test method that touches `@MainActor` state is annotated `@MainActor`.
- [ ] Test target uses `Settings.modularTests` (includes `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`).
- [ ] Build passes with zero warnings: `xcodebuild ... test` should say `** TEST SUCCEEDED **` with no `.swift:N: error:` lines in the output.
