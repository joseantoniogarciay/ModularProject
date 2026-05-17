import Core
import SharedUI
import UIKit

@MainActor
final class RegisterViewController: UIViewController {
    private let session: any AuthSession
    private let onSuccess: () -> Void

    private let usernameField = UITextField()
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let registerButton = UIButton(type: .system)
    private let errorLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(session: any AuthSession, onSuccess: @escaping () -> Void) {
        self.session = session
        self.onSuccess = onSuccess
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = CoreStrings.accountRegisterScreenTitle
        configureViews()
    }

    private func configureViews() {
        configureTextField(usernameField, placeholder: CoreStrings.accountUsernamePlaceholder)
        usernameField.textContentType = .username
        usernameField.autocapitalizationType = .none
        usernameField.autocorrectionType = .no

        configureTextField(emailField, placeholder: CoreStrings.accountEmailPlaceholder)
        emailField.keyboardType = .emailAddress
        emailField.textContentType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no

        configureTextField(passwordField, placeholder: CoreStrings.accountPasswordPlaceholder)
        passwordField.isSecureTextEntry = true
        passwordField.textContentType = .newPassword

        registerButton.setTitle(CoreStrings.accountRegisterButton, for: .normal)
        registerButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
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
            usernameField,
            emailField,
            passwordField,
            registerButton,
            errorLabel,
            spinner,
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
        ])
    }

    private func configureTextField(_ field: UITextField, placeholder: String) {
        field.placeholder = placeholder
        field.borderStyle = .roundedRect
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
    }

    @objc private func registerTapped() {
        let username = usernameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let email = emailField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let password = passwordField.text ?? ""
        guard !username.isEmpty, !email.isEmpty, !password.isEmpty else { return }
        setBusy(true)
        Task { [session, onSuccess] in
            do {
                try await session.register(username: username, email: email, password: password)
                onSuccess()
            } catch let error as AuthError {
                showError(message(for: error))
                setBusy(false)
            } catch {
                showError(CoreStrings.accountErrorGeneric)
                setBusy(false)
            }
        }
    }

    private func setBusy(_ busy: Bool) {
        registerButton.isEnabled = !busy
        usernameField.isEnabled = !busy
        emailField.isEnabled = !busy
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
        case .usernameOrEmailTaken:
            return CoreStrings.accountErrorTaken
        default:
            return CoreStrings.accountErrorGeneric
        }
    }
}
