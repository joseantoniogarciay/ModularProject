import Core
import UIKit

public protocol PokemonCoordinatorDelegate: AnyObject {
    // Cross-feature transitions land here as the feature graph grows.
}

@MainActor
public final class PokemonCoordinator: Coordinator {
    public weak var delegate: (any PokemonCoordinatorDelegate)?

    private let navigationController: UINavigationController
    private let repository: any PokemonRepository

    public init(
        navigationController: UINavigationController,
        repository: any PokemonRepository
    ) {
        self.navigationController = navigationController
        self.repository = repository
    }

    public func start() {
        let listVC = PokemonListViewController(
            repository: repository,
            onSelect: { [weak self] pokemon in
                self?.showDetail(for: pokemon)
            }
        )
        navigationController.setViewControllers([listVC], animated: false)
    }

    private func showDetail(for pokemon: Pokemon) {
        let detailVC = PokemonDetailViewController(
            repository: repository,
            pokemon: pokemon
        )
        navigationController.pushViewController(detailVC, animated: true)
    }
}
