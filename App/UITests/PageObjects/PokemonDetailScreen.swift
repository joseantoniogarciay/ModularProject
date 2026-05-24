import XCTest

/// Page Object for the Pokémon detail screen.
///
/// Encapsulates all XCUI element queries and gestures for the detail screen.
/// Test methods must call Page Object APIs only — no raw XCUIElement access in test code.
///
/// `@MainActor` is required because all `XCUIApplication` properties and methods are
/// main-actor-isolated under Swift 6 strict concurrency. Page Object instances are
/// created and used exclusively from `@MainActor`-annotated test methods.
@MainActor
struct PokemonDetailScreen {
    private let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Elements

    /// The scroll view wrapping all detail content
    /// (accessibilityIdentifier = "pokemon.detail.scroll").
    var scrollView: XCUIElement {
        app.scrollViews["pokemon.detail.scroll"]
    }

    /// The activity indicator shown while detail data is loading
    /// (accessibilityIdentifier = "pokemon.detail.loading").
    var loadingIndicator: XCUIElement {
        app.activityIndicators["pokemon.detail.loading"]
    }

    /// The "Base Stats" section header label
    /// (accessibilityIdentifier = "pokemon.detail.stats-header").
    var statsHeader: XCUIElement {
        app.staticTexts.matching(identifier: "pokemon.detail.stats-header").firstMatch
    }

    /// The retry button shown when the detail load fails
    /// (accessibilityIdentifier = "pokemon.detail.retry.button").
    var retryButton: XCUIElement {
        app.buttons["pokemon.detail.retry.button"]
    }

    // MARK: - Queries

    /// Returns the title of the currently visible navigation bar.
    var navigationTitle: String {
        app.navigationBars.firstMatch.identifier
    }

    /// Blocks until the scroll view appears or `timeout` elapses.
    @discardableResult
    func waitForScrollView(timeout: TimeInterval = 3) -> Bool {
        scrollView.waitForExistence(timeout: timeout)
    }

    /// Blocks until the "Base Stats" header appears, signalling that the async
    /// detail load completed and `render()` was called. Returns true if found.
    @discardableResult
    func waitForStats(timeout: TimeInterval = 5) -> Bool {
        statsHeader.waitForExistence(timeout: timeout)
    }

    // MARK: - Actions

    /// Taps the back button in the navigation bar and returns the list Page Object.
    @discardableResult
    func tapBack() -> PokemonListScreen {
        app.navigationBars.firstMatch.buttons.firstMatch.tap()
        return PokemonListScreen(app: app)
    }
}
