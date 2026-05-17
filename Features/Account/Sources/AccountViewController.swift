import Core
import SharedUI
import UIKit

@MainActor
final class AccountViewController: UIViewController {
    private let session: any AuthSession
    private weak var navigator: (any AccountNavigator)?
    private var observationTask: Task<Void, Never>?
    private var currentChild: UIViewController?
    private var renderedState: AuthState?

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
        view.backgroundColor = .systemBackground
        title = CoreStrings.accountTitle

        observationTask = Task { [weak self] in
            guard let self else { return }
            for await state in self.session.states() {
                self.render(state)
            }
        }
    }

    private func render(_ state: AuthState) {
        defer { renderedState = state }

        switch (renderedState, state) {
        case (.unknown?, .unknown), (.anonymous?, .anonymous):
            return
        case let (.authenticated(previous)?, .authenticated(new)) where previous.id == new.id:
            (currentChild as? LoggedInViewController)?.update(user: new)
            return
        default:
            break
        }

        switch state {
        case .unknown:
            swap(in: makeLoadingViewController())
        case .anonymous:
            let loggedOut = LoggedOutViewController(session: session, navigator: navigator)
            swap(in: loggedOut)
        case .authenticated(let user):
            let loggedIn = LoggedInViewController(session: session, user: user)
            swap(in: loggedIn)
        }
    }

    private func makeLoadingViewController() -> UIViewController {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .systemBackground
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        viewController.view.addSubview(spinner)
        spinner.centerInSuperview()
        return viewController
    }

    private func swap(in child: UIViewController) {
        if let currentChild {
            currentChild.willMove(toParent: nil)
            currentChild.view.removeFromSuperview()
            currentChild.removeFromParent()
        }
        addChild(child)
        child.view.frame = view.bounds
        view.addSubview(child.view)
        child.view.pinEdges(to: view)
        child.didMove(toParent: self)
        currentChild = child
    }
}
