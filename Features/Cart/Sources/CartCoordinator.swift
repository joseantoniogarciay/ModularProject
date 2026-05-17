import Core
import UIKit

@MainActor
public final class CartCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let cartRepository: any CartRepository
    private let productsRepository: any ProductsRepository
    private let onSimulateSessionExpiration: @MainActor () async -> Void

    public init(
        navigationController: UINavigationController,
        cartRepository: any CartRepository,
        productsRepository: any ProductsRepository,
        onSimulateSessionExpiration: @escaping @MainActor () async -> Void
    ) {
        self.navigationController = navigationController
        self.cartRepository = cartRepository
        self.productsRepository = productsRepository
        self.onSimulateSessionExpiration = onSimulateSessionExpiration
    }

    public func start() {
        let cartVC = CartViewController(
            cartRepository: cartRepository,
            productsRepository: productsRepository,
            onSimulateSessionExpiration: onSimulateSessionExpiration
        )
        navigationController.pushViewController(cartVC, animated: true)
    }
}
