import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var rootCoordinator: AppRootCoordinator?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        let coordinator = AppRootCoordinator(
            window: window,
            dependencies: AppDependencies.live()
        )
        rootCoordinator = coordinator
        coordinator.start()
    }
}
