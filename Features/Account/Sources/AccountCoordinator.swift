import Core
import UIKit

public protocol AccountCoordinatorDelegate: AnyObject {
    // Cross-feature transitions land here as the feature graph grows.
}

@MainActor
public final class AccountCoordinator: Coordinator {
    public weak var delegate: (any AccountCoordinatorDelegate)?

    private let navigationController: UINavigationController
    private let session: any AuthSession

    public init(navigationController: UINavigationController, session: any AuthSession) {
        self.navigationController = navigationController
        self.session = session
    }

    public func start() {
        let accountVC = AccountViewController(session: session, navigator: self)
        navigationController.setViewControllers([accountVC], animated: false)
    }

    fileprivate func showRegister() {
        let registerVC = RegisterViewController(session: session) { [weak self] in
            self?.navigationController.popViewController(animated: true)
        }
        navigationController.pushViewController(registerVC, animated: true)
    }
}

extension AccountCoordinator: AccountNavigator {
    func accountDidRequestRegister() {
        showRegister()
    }
}
