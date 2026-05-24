#if DEBUG
import Core
import Foundation
import Pokemon
import SharedUI

// MARK: - UI test dependency graph

extension AppDependencies {
    /// Replaces every network-dependent repository with an in-memory stub so UI tests
    /// run without a live server and finish in milliseconds.
    /// Activated by passing `--uitesting` in `XCUIApplication.launchArguments`.
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

// MARK: - Stubs

@MainActor
private final class UITestAuthSession: AuthSession {
    var authState: AuthState { .anonymous(.initial) }
    func authStates() -> AsyncStream<AuthState> { AsyncStream { _ in } }
    func restore() async {}
    func login(identifier: String, password: String) async throws(LoginError) {}
    func register(username: String, email: String, password: String) async throws(SignUpError) {}
    func refreshCurrentUser() async throws(CurrentUserError) {}
    func logout() async {}
    func expireSession() async {}
}

private struct UITestCartRepository: CartRepository {
    func get() async throws(CartFetchError) -> Cart { Cart(items: [], total: 0) }
    func addItem(productId: String) async throws(CartAddItemError) -> Cart { Cart(items: [], total: 0) }
}

private struct UITestProductsRepository: ProductsRepository {
    func list() async throws(ProductsListError) -> [Product] { [] }
}
#endif
