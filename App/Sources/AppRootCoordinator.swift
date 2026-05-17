import Account
import Core
import Pokemon
import UIKit

@MainActor
final class AppRootCoordinator: Coordinator {
    private let window: UIWindow
    private let dependencies: AppDependencies
    private var children: [any Coordinator] = []

    init(window: UIWindow, dependencies: AppDependencies) {
        self.window = window
        self.dependencies = dependencies
    }

    func start() {
        let tabBarController = UITabBarController()

        let pokemonNav = UINavigationController()
        pokemonNav.tabBarItem = UITabBarItem(
            title: CoreStrings.pokemonTitle,
            image: UIImage(systemName: "list.bullet"),
            selectedImage: nil
        )
        let pokemonCoordinator = PokemonCoordinator(
            navigationController: pokemonNav,
            repository: dependencies.pokemonRepository,
            imageLoader: dependencies.imageLoader
        )
        pokemonCoordinator.delegate = self
        pokemonCoordinator.start()
        children.append(pokemonCoordinator)

        let accountNav = UINavigationController()
        accountNav.tabBarItem = UITabBarItem(
            title: CoreStrings.accountTitle,
            image: UIImage(systemName: "person.crop.circle"),
            selectedImage: nil
        )
        let accountCoordinator = AccountCoordinator(navigationController: accountNav)
        accountCoordinator.delegate = self
        accountCoordinator.start()
        children.append(accountCoordinator)

        tabBarController.viewControllers = [pokemonNav, accountNav]
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
    }
}

extension AppRootCoordinator: PokemonCoordinatorDelegate {}
extension AppRootCoordinator: AccountCoordinatorDelegate {}
