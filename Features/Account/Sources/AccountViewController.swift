import Core
import SharedUI
import UIKit

@MainActor
final class AccountViewController: UIViewController {
    private let session: any AuthSession
    private weak var navigator: (any AccountNavigator)?
    private var observationTask: Task<Void, Never>?
    private var currentChild: UIViewController?
    private var renderedAuthState: AuthState?
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(session: any AuthSession, navigator: any AccountNavigator) {
        self.session = session
        self.navigator = navigator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    deinit {
        observationTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SharedUIAsset.background.color

        observationTask = Task { [weak self] in
            guard let self else { return }
            for await authState in self.session.authStates() {
                self.render(authState)
            }
        }

        Task { [session] in
            await session.restore()
        }
    }

    private func render(_ authState: AuthState) {
        defer { renderedAuthState = authState }

        switch (renderedAuthState, authState) {
        case (.unknown?, .unknown):
            return
        case let (.anonymous(prev)?, .anonymous(new)) where prev == new:
            return
        case let (.authenticated(previous)?, .authenticated(new)) where previous.id == new.id:
            (currentChild as? LoggedInViewController)?.update(user: new)
            return
        default:
            break
        }

        switch authState {
        case .unknown:
            swap(in: makeLoadingViewController())
        case .anonymous(let reason):
            navigationItem.rightBarButtonItem = nil
            let loggedOut = LoggedOutViewController(session: session, navigator: navigator)
            swap(in: loggedOut)
            view.layoutIfNeeded()
            navigationController?.popToRootViewController(animated: true)
            presentBanner(for: reason)
        case .authenticated(let user):
            let logoutItem = UIBarButtonItem(
                symbolName: "rectangle.portrait.and.arrow.right",
                accessibilityLabel: CoreStrings.accountLogoutButton,
                target: self,
                action: #selector(logoutTapped)
            )
            logoutItem.tintColor = .systemRed
            navigationItem.rightBarButtonItem = logoutItem
            let loggedIn = LoggedInViewController(session: session, user: user, navigator: navigator)
            swap(in: loggedIn)
        }
    }

    private func presentBanner(for reason: AnonymousReason) {
        switch reason {
        case .sessionExpired:
            BannerCenter.shared.show(
                BannerPayload(
                    message: CoreStrings.accountSessionExpiredMessage,
                    style: .warning,
                    iconSystemName: "exclamationmark.triangle.fill"
                )
            )
        case .initial, .userLoggedOut:
            break
        }
    }

    @objc private func logoutTapped() {
        let dialog = ConfirmationDialogViewController(
            payload: ConfirmationDialogPayload(
                iconSystemName: "rectangle.portrait.and.arrow.right",
                iconTintColor: .systemRed,
                title: CoreStrings.accountLogoutConfirmTitle,
                message: CoreStrings.accountLogoutConfirmMessage,
                confirm: ConfirmationDialogAction(
                    title: CoreStrings.accountLogoutConfirmButton,
                    handler: { [weak self] in self?.performLogout() }
                ),
                cancel: ConfirmationDialogAction(title: CoreStrings.accountCancelButton)
            )
        )
        present(dialog, animated: true)
    }

    private func performLogout() {
        spinner.startAnimating()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: spinner)
        Task { [session] in
            await session.logout()
        }
    }

    private func makeLoadingViewController() -> UIViewController {
        let viewController = UIViewController()
        viewController.view.backgroundColor = SharedUIAsset.background.color
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        viewController.view.addSubview(spinner)
        spinner.centerInSuperview()
        return viewController
    }

    private func swap(in child: UIViewController) {
        let outgoing = currentChild
        addChild(child)
        child.view.frame = view.bounds
        view.addSubview(child.view)
        child.view.pinEdges(to: view)

        guard let outgoing else {
            child.didMove(toParent: self)
            currentChild = child
            return
        }

        outgoing.willMove(toParent: nil)
        child.view.alpha = 0
        currentChild = child

        let finalize = {
            outgoing.view.removeFromSuperview()
            outgoing.removeFromParent()
            child.didMove(toParent: self)
        }

        guard !UIAccessibility.isReduceMotionEnabled else {
            child.view.alpha = 1
            outgoing.view.alpha = 0
            finalize()
            return
        }

        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.allowUserInteraction],
            animations: {
                child.view.alpha = 1
                outgoing.view.alpha = 0
            },
            completion: { _ in finalize() }
        )
    }
}
