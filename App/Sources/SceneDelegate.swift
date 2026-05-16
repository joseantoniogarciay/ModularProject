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
        let listVC = PokemonListViewController(
            listUseCase: dependencies.makeListPokemonUseCase(),
            onSelect: { _ in
                // Detail navigation lands in a follow-up commit.
            }
        )
        window.rootViewController = UINavigationController(rootViewController: listVC)

        self.window = window
        window.makeKeyAndVisible()
    }
}
