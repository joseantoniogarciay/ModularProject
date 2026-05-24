import XCTest

/// Page Object for the Pokémon list screen.
///
/// Encapsulates all XCUI element queries and gestures for this screen.
/// Test methods must call Page Object APIs only — no raw XCUIElement access in test code.
///
/// `@MainActor` is required because all `XCUIApplication` properties and methods are
/// main-actor-isolated under Swift 6 strict concurrency. Page Object instances are
/// created and used exclusively from `@MainActor`-annotated test methods.
@MainActor
struct PokemonListScreen {
    private let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Elements

    /// The main table (accessibilityIdentifier = "pokemon.list.table").
    var table: XCUIElement {
        app.tables["pokemon.list.table"]
    }

    /// The retry button inside the full-screen error view
    /// (accessibilityIdentifier = "pokemon.list.retry.button").
    var retryButton: XCUIElement {
        app.buttons["pokemon.list.retry.button"]
    }

    // MARK: - Queries

    /// Blocks until the list table appears or `timeout` elapses. Returns true if found.
    @discardableResult
    func waitForTable(timeout: TimeInterval = 3) -> Bool {
        table.waitForExistence(timeout: timeout)
    }

    /// Blocks until the full-screen retry button appears or `timeout` elapses.
    @discardableResult
    func waitForRetry(timeout: TimeInterval = 3) -> Bool {
        retryButton.waitForExistence(timeout: timeout)
    }

    /// Returns the cell for the Pokémon with the given name (case-insensitive).
    /// Matched via `accessibilityIdentifier = "pokemon.cell.<name.lowercased()>"`.
    func cell(named name: String) -> XCUIElement {
        app.cells["pokemon.cell.\(name.lowercased())"]
    }

    // MARK: - Actions

    /// Taps the cell for the named Pokémon and returns the resulting detail Page Object.
    @discardableResult
    func tapCell(named name: String) -> PokemonDetailScreen {
        cell(named: name).tap()
        return PokemonDetailScreen(app: app)
    }
}
