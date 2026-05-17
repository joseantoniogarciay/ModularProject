import Core
import SharedUI
import UIKit

@MainActor
final class LoggedInViewController: UIViewController {
    private let session: any AuthSession
    private var user: User

    private let greetingLabel = UILabel()
    private let emailLabel = UILabel()
    private let roleLabel = UILabel()
    private let idLabel = UILabel()
    private let logoutButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(session: any AuthSession, user: User) {
        self.session = session
        self.user = user
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
        view.backgroundColor = .systemBackground
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
            label.textColor = .secondaryLabel
            label.numberOfLines = 0
        }

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
            logoutButton,
            spinner,
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
        ])
    }

    private func bind(to user: User) {
        greetingLabel.text = CoreStrings.accountGreetingFormat(user.username)
        emailLabel.text = CoreStrings.accountProfileEmailFormat(user.email)
        roleLabel.text = CoreStrings.accountProfileRoleFormat(user.role ?? "-")
        idLabel.text = CoreStrings.accountProfileIdFormat(user.id)
    }

    @objc private func logoutTapped() {
        spinner.startAnimating()
        logoutButton.isEnabled = false
        Task { [session] in
            await session.logout()
        }
    }
}
