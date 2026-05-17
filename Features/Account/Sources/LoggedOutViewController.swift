import Core
import SharedUI
import UIKit

@MainActor
final class LoggedOutViewController: UIViewController {
    private let session: any AuthSession
    private weak var navigator: (any AccountNavigator)?

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let identifierField = UITextField()
    private let passwordField = UITextField()
    private let loginButton = UIButton(type: .system)
    private let registerButton = UIButton(type: .system)
    private let errorLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(session: any AuthSession, navigator: (any AccountNavigator)?) {
        self.session = session
        self.navigator = navigator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureViews()
    }

    private func configureViews() {
        titleLabel.text = CoreStrings.accountLoggedOutTitle
        titleLabel.font = .preferredFont(forTextStyle: .title1)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center

        subtitleLabel.text = CoreStrings.accountLoggedOutSubtitle
        subtitleLabel.font = .preferredFont(forTextStyle: .body)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        configureTextField(identifierField, placeholder: CoreStrings.accountUsernameOrEmailPlaceholder)
        identifierField.textContentType = .username
        identifierField.autocapitalizationType = .none
        identifierField.autocorrectionType = .no

        configureTextField(passwordField, placeholder: CoreStrings.accountPasswordPlaceholder)
        passwordField.isSecureTextEntry = true
        passwordField.textContentType = .password

        loginButton.setTitle(CoreStrings.accountLoginButton, for: .normal)
        loginButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        loginButton.titleLabel?.adjustsFontForContentSizeCategory = true
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)

        registerButton.setTitle(CoreStrings.accountRegisterButton, for: .normal)
        registerButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        registerButton.titleLabel?.adjustsFontForContentSizeCategory = true
        registerButton.addTarget(self, action: #selector(registerTapped), for: .touchUpInside)

        errorLabel.font = .preferredFont(forTextStyle: .footnote)
        errorLabel.adjustsFontForContentSizeCategory = true
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        errorLabel.isHidden = true

        spinner.hidesWhenStopped = true

        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel,
            identifierField,
            passwordField,
            loginButton,
            errorLabel,
            spinner,
            registerButton,
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func configureTextField(_ field: UITextField, placeholder: String) {
        field.placeholder = placeholder
        field.borderStyle = .roundedRect
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
    }

    @objc private func loginTapped() {
        let identifier = identifierField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let password = passwordField.text ?? ""
        guard !identifier.isEmpty, !password.isEmpty else { return }
        setBusy(true)
        Task { [session] in
            do {
                try await session.login(identifier: identifier, password: password)
            } catch let error as AuthError {
                showError(message(for: error))
                setBusy(false)
            } catch {
                showError(CoreStrings.accountErrorGeneric)
                setBusy(false)
            }
        }
    }

    @objc private func registerTapped() {
        navigator?.accountDidRequestRegister()
    }

    private func setBusy(_ busy: Bool) {
        loginButton.isEnabled = !busy
        registerButton.isEnabled = !busy
        identifierField.isEnabled = !busy
        passwordField.isEnabled = !busy
        if busy {
            errorLabel.isHidden = true
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
    }

    private func showError(_ text: String) {
        errorLabel.text = text
        errorLabel.isHidden = false
    }

    private func message(for error: AuthError) -> String {
        switch error {
        case .invalidCredentials:
            return CoreStrings.accountErrorInvalidCredentials
        default:
            return CoreStrings.accountErrorGeneric
        }
    }
}
