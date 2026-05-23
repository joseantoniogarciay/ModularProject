import Core
import SharedUI
import UIKit

@MainActor
final class LoggedInViewController: UIViewController {
    private let session: any AuthSession
    private weak var navigator: (any AccountNavigator)?
    private var user: User

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let greetingLabel = UILabel()
    private let emailLabel = UILabel()
    private let roleLabel = UILabel()
    private let idLabel = UILabel()
    private let cartButton = UIButton(type: .system)
    private let logoutButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(session: any AuthSession, user: User, navigator: (any AccountNavigator)?) {
        self.session = session
        self.user = user
        self.navigator = navigator
        super.init(nibName: nil, bundle: nil)
    }

    func update(user: User) {
        self.user = user
        guard isViewLoaded else { return }
        bind(to: user)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = CoreAsset.background.color
        configureViews()
        bind(to: user)
        Task { [session] in
            do {
                try await session.refreshCurrentUser()
            } catch {
                // The session will downgrade itself if refresh fails irrecoverably.
            }
        }
    }

    private func configureViews() {
        greetingLabel.font = .preferredFont(forTextStyle: .title1)
        greetingLabel.adjustsFontForContentSizeCategory = true
        greetingLabel.numberOfLines = 0

        for label in [emailLabel, roleLabel, idLabel] {
            label.font = .preferredFont(forTextStyle: .body)
            label.adjustsFontForContentSizeCategory = true
            label.textColor = CoreAsset.secondaryText.color
            label.numberOfLines = 0
        }

        cartButton.setTitle(CoreStrings.accountCartButton, for: .normal)
        cartButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        cartButton.titleLabel?.adjustsFontForContentSizeCategory = true
        cartButton.addTarget(self, action: #selector(cartTapped), for: .touchUpInside)

        logoutButton.setTitle(CoreStrings.accountLogoutButton, for: .normal)
        logoutButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        logoutButton.titleLabel?.adjustsFontForContentSizeCategory = true
        logoutButton.tintColor = .systemRed
        logoutButton.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)

        spinner.hidesWhenStopped = true

        let stack = UIStackView(arrangedSubviews: [
            greetingLabel,
            emailLabel,
            roleLabel,
            idLabel,
            cartButton,
            logoutButton,
            spinner,
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        scrollView.pinEdges(to: view)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24),
        ])
    }

    private func bind(to user: User) {
        greetingLabel.text = CoreStrings.accountGreetingFormat(user.username)
        emailLabel.text = CoreStrings.accountProfileEmailFormat(user.email)
        roleLabel.text = CoreStrings.accountProfileRoleFormat(user.role ?? "-")
        idLabel.text = CoreStrings.accountProfileIdFormat(user.id)
    }

    @objc private func cartTapped() {
        navigator?.accountDidRequestCart()
    }

    @objc private func logoutTapped() {
        spinner.startAnimating()
        logoutButton.isEnabled = false
        Task { [session] in
            await session.logout()
        }
    }
}
