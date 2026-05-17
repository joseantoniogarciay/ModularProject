import Core
import UIKit

public protocol AccountCoordinatorDelegate: AnyObject {
    // Cross-feature transitions land here as the feature graph grows.
}

@MainActor
public final class AccountCoordinator: Coordinator {
    public weak var delegate: (any AccountCoordinatorDelegate)?

    private let navigationController: UINavigationController

    public init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    public func start() {
        let accountVC = AccountViewController()
        navigationController.setViewControllers([accountVC], animated: false)
    }
}
