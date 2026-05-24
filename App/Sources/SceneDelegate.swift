import Core
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var rootCoordinator: AppRootCoordinator?
    private var pushRouter: PushNotificationRouter?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        let dependencies: AppDependencies
        if args.contains("--uitesting-list-error") {
            dependencies = AppDependencies.uitestingWithListError()
        } else if args.contains("--uitesting") {
            dependencies = AppDependencies.uitesting()
        } else {
            dependencies = AppDependencies.live()
        }
        #else
        let dependencies = AppDependencies.live()
        #endif
        window.overrideUserInterfaceStyle = dependencies.themeStore.current.uiStyle

        let coordinator = AppRootCoordinator(
            window: window,
            dependencies: dependencies
        )
        rootCoordinator = coordinator
        coordinator.start()

        pushRouter = PushNotificationRouter(dependencies: dependencies)
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
