import Pokemon
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)

        let dependencies = AppDependencies.live()
        let navigationController = UINavigationController()
        let listVC = PokemonListViewController(
            repository: dependencies.pokemonRepository,
            onSelect: { [weak navigationController] pokemon in
                let detailVC = PokemonDetailViewController(
                    repository: dependencies.pokemonRepository,
                    pokemon: pokemon
                )
                navigationController?.pushViewController(detailVC, animated: true)
            }
        )
        navigationController.viewControllers = [listVC]
        window.rootViewController = navigationController

        self.window = window
        window.makeKeyAndVisible()
    }
}
