import Core
import SharedUI
import UIKit

public protocol PokemonCoordinatorDelegate: AnyObject {
    // Cross-feature transitions land here as the feature graph grows.
}

@MainActor
public final class PokemonCoordinator: Coordinator {
    public weak var delegate: (any PokemonCoordinatorDelegate)?

    private let navigationController: UINavigationController
    private let repository: any PokemonRepository
    private let imageLoader: any ImageLoader
    private let themeStore: any ThemeStore
    private let notificationScheduler: any LocalNotificationScheduling

    public init(
        navigationController: UINavigationController,
        repository: any PokemonRepository,
        imageLoader: any ImageLoader,
        themeStore: any ThemeStore,
        notificationScheduler: any LocalNotificationScheduling
    ) {
        self.navigationController = navigationController
        self.repository = repository
        self.imageLoader = imageLoader
        self.themeStore = themeStore
        self.notificationScheduler = notificationScheduler
    }

    public func start() {
        let listVC = PokemonListViewController(
            repository: repository,
            imageLoader: imageLoader,
            themeStore: themeStore,
            notificationScheduler: notificationScheduler,
            onSelect: { [weak self] pokemon in
                self?.showDetail(for: pokemon)
            }
        )
        navigationController.setViewControllers([listVC], animated: false)
    }

    private func showDetail(for pokemon: Pokemon) {
        let detailVC = PokemonDetailViewController(
            repository: repository,
            pokemon: pokemon,
            imageLoader: imageLoader
        )
        navigationController.pushViewController(detailVC, animated: true)
    }
}
