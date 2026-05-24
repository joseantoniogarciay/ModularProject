import XCTest

// MARK: - Happy-path use cases (fake network, all stubs succeed)

/// Use-case tests for the Pokémon flow with fake network.
///
/// Launched with `--uitesting` → `AppDependencies.uitesting()` →
/// `PreviewPokemonRepository` returns 12 sample Pokémon instantly.
/// No server required. Runs on any iOS 17+ simulator.
final class PokemonUseCaseTests: UITestCase {

    // MARK: UC-1: List loads

    /// The list screen appears and shows at least one Pokémon card.
    @MainActor
    func testListLoadsAndShowsPokemon() {
        let list = PokemonListScreen(app: app)
        XCTAssertTrue(list.waitForTable(), "List table must appear with fake data")
        XCTAssertGreaterThan(list.table.cells.count, 0, "At least one Pokémon cell must be visible")
    }

    // MARK: UC-2: Cell content

    /// The first cell shows the correct name and Pokédex number.
    @MainActor
    func testFirstCellShowsNameAndNumber() {
        let list = PokemonListScreen(app: app)
        XCTAssertTrue(list.waitForTable(), "List table must appear before checking cell content")

        let cell = list.cell(named: "bulbasaur")
        XCTAssertTrue(
            cell.waitForExistence(timeout: 3),
            "Bulbasaur cell must be visible (accessibilityIdentifier = 'pokemon.cell.bulbasaur')"
        )
        XCTAssertTrue(cell.staticTexts["Bulbasaur"].exists, "Cell must display 'Bulbasaur'")
        XCTAssertTrue(cell.staticTexts["#001"].exists, "Cell must display '#001'")
    }

    // MARK: UC-3: List → Detail navigation

    /// Tapping a Pokémon pushes the detail screen and shows the correct nav title.
    @MainActor
    func testTapPokemonNavigatesToDetail() {
        let list = PokemonListScreen(app: app)
        XCTAssertTrue(list.waitForTable())

        let detail = list.tapCell(named: "bulbasaur")
        XCTAssertTrue(detail.waitForScrollView(), "Detail scroll view must appear after tap")
        XCTAssertEqual(
            detail.navigationTitle,
            "Bulbasaur",
            "Navigation bar title must match the tapped Pokémon's capitalized name"
        )
    }

    // MARK: UC-4: Detail loads stats

    /// After navigating to detail, the stats section appears once the async load resolves.
    @MainActor
    func testDetailLoadsStats() {
        let list = PokemonListScreen(app: app)
        XCTAssertTrue(list.waitForTable())

        let detail = list.tapCell(named: "bulbasaur")
        XCTAssertTrue(
            detail.waitForStats(),
            "'Base Stats' header must appear once the detail async load resolves"
        )
        XCTAssertFalse(
            detail.loadingIndicator.exists,
            "Activity indicator must be hidden after stats render (hidesWhenStopped = true)"
        )
    }

    // MARK: UC-5: Detail → List back navigation

    /// Tapping back from the detail screen returns to the Pokémon list.
    @MainActor
    func testBackFromDetailReturnsToList() {
        let list = PokemonListScreen(app: app)
        XCTAssertTrue(list.waitForTable())

        let detail = list.tapCell(named: "bulbasaur")
        XCTAssertTrue(detail.waitForScrollView(), "Detail scroll view must appear before tapping back")

        let listAgain = detail.tapBack()
        XCTAssertTrue(
            listAgain.waitForTable(),
            "List table must be visible again after back navigation"
        )
    }

    // MARK: UC-6: Navigate to a different Pokémon

    /// Tapping a non-first cell also navigates to the correct detail screen.
    @MainActor
    func testTapSecondPokemonNavigatesToCorrectDetail() {
        let list = PokemonListScreen(app: app)
        XCTAssertTrue(list.waitForTable())

        let detail = list.tapCell(named: "ivysaur")
        XCTAssertTrue(detail.waitForScrollView(), "Detail scroll view must appear after tapping Ivysaur")
        XCTAssertEqual(
            detail.navigationTitle,
            "Ivysaur",
            "Navigation bar title must match the tapped Pokémon's name"
        )
    }
}

// MARK: - Error-state use cases

/// Use-case tests for the Pokémon list when the repository fails.
///
/// Launched with `--uitesting-list-error` → `AppDependencies.uitestingWithListError()` →
/// `UITestErrorPokemonRepository.list()` always throws `.noConnection`.
final class PokemonListErrorTests: UITestCase {

    override var launchArguments: [String] { ["--uitesting-list-error"] }

    // MARK: UC-7: List error state

    /// When the initial list load fails, the full-screen retry view is shown.
    @MainActor
    func testListErrorStateShowsRetryButton() {
        let list = PokemonListScreen(app: app)
        XCTAssertTrue(
            list.waitForRetry(),
            "Retry button must appear when the initial list load throws .noConnection"
        )
        XCTAssertFalse(
            list.table.isHittable,
            "List table must not be hittable when the full-screen error view is shown"
        )
    }
}
