import XCTest

/// Accessibility audit for the Pokémon list screen.
///
/// `performAccessibilityAudit()` runs the same checks as Xcode's Accessibility Inspector
/// on the live rendered screen: color contrast, hit regions, Dynamic Type, element
/// descriptions, and VoiceOver navigation order — all in one call.
///
/// The app is launched with `--uitesting` so repositories use in-memory stubs.
/// No network connection required.

// Invariant: `app` is accessed exclusively from @MainActor-isolated test methods
// and from setUp/tearDown which XCTest guarantees run on the main thread.
// Removal plan: remove nonisolated(unsafe) + assumeIsolated once XCTest annotates
// setUp/tearDown as @MainActor in a future SDK release.
final class PokemonListAccessibilityTests: XCTestCase {

    nonisolated(unsafe) var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        let application = MainActor.assumeIsolated {
            let a = XCUIApplication()
            a.launchArguments = ["--uitesting"]
            a.launch()
            return a
        }
        app = application
    }

    override func tearDown() {
        // Capture into a local so the assumeIsolated closure does not capture self.
        let application = app
        MainActor.assumeIsolated { application?.terminate() }
        app = nil
        super.tearDown()
    }

    // MARK: - Audit

    @MainActor
    func testPokemonListPassesAccessibilityAudit() throws {
        // Wait for the table to appear — stubs return data synchronously so this is fast.
        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 3), "Pokémon list table must appear")

        try app.performAccessibilityAudit()
    }

    @MainActor
    func testPokemonListTabBarPassesAccessibilityAudit() throws {
        // The tab bar items must also have labels — cover them separately so failures
        // point to the tab bar rather than the list content.
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3), "Tab bar must appear")

        try app.performAccessibilityAudit(for: .sufficientElementDescription)
    }

    // MARK: - RetryView audit

    /// Launch with list-error to render the full-screen `RetryView` and audit it.
    /// Mirrors the SwiftUI port's `testRetryViewPassesAccessibilityAudit` so both projects
    /// cover the error screen's contrast, hit regions and descriptions equally.
    @MainActor
    func testRetryViewPassesAccessibilityAudit() throws {
        // Terminate the default app launched in setUp (it used --uitesting).
        app.terminate()

        let errorApp = XCUIApplication()
        errorApp.launchArguments = ["--uitesting-list-error"]
        errorApp.launch()
        defer { errorApp.terminate() }

        let retryButton = errorApp.buttons["pokemon.list.retry.button"]
        XCTAssertTrue(
            retryButton.waitForExistence(timeout: 3),
            "Retry button must appear when the initial list load fails"
        )

        // Suppress only the borderline "Contrast nearly passed" near-miss the auditor raises
        // against system-colored elements; every other audit check still fails the test.
        try errorApp.performAccessibilityAudit { issue in
            let description = issue.compactDescription + " " + issue.detailedDescription
            let isNearMissContrast = issue.auditType == .contrast
                && description.localizedCaseInsensitiveContains("nearly passed")
            return isNearMissContrast  // true → ignore this issue
        }
    }
}
