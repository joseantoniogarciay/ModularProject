import Core
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

        let dependencies = AppDependencies.live()
        window.overrideUserInterfaceStyle = dependencies.themeStore.current.uiStyle

        let coordinator = AppRootCoordinator(
            window: window,
            dependencies: dependencies
        )
        rootCoordinator = coordinator
        coordinator.start()
    }
}

private extension ThemePreference {
    var uiStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}
