import Core
import SharedUI
import UIKit

@MainActor
final class RegisterViewController: UIViewController {
    private let session: any AuthSession
    private let onSuccess: () -> Void

    private let usernameField = ValidatedTextField(
        placeholder: CoreStrings.accountUsernamePlaceholder,
        validators: [TextFieldValidators.notEmpty(CoreStrings.accountErrorFieldRequired)]
    )
    private let emailField = ValidatedTextField(
        placeholder: CoreStrings.accountEmailPlaceholder,
        validators: [
            TextFieldValidators.notEmpty(CoreStrings.accountErrorFieldRequired),
            TextFieldValidators.email(CoreStrings.accountErrorInvalidEmail),
        ]
    )
    private let passwordField = ValidatedTextField(
        placeholder: CoreStrings.accountPasswordPlaceholder,
        validators: [TextFieldValidators.notEmpty(CoreStrings.accountErrorFieldRequired)]
    )
    private let registerButton = UIButton(type: .system)
    private let errorLabel = UILabel()
    private let busyOverlay = BusyOverlay()

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
        view.backgroundColor = CoreAsset.background.color
        title = CoreStrings.accountRegisterScreenTitle
        configureViews()
    }

    private func configureViews() {
        usernameField.textField.textContentType = .username
        usernameField.textField.autocapitalizationType = .none
        usernameField.textField.autocorrectionType = .no

        emailField.textField.keyboardType = .emailAddress
        emailField.textField.textContentType = .emailAddress
        emailField.textField.autocapitalizationType = .none
        emailField.textField.autocorrectionType = .no

        passwordField.textField.isSecureTextEntry = true
        passwordField.textField.textContentType = .newPassword

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

        let stack = UIStackView(arrangedSubviews: [
            usernameField,
            emailField,
            passwordField,
            registerButton,
            errorLabel,
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

    @objc private func registerTapped() {
        let usernameValid = usernameField.validate()
        let emailValid = emailField.validate()
        let passwordValid = passwordField.validate()
        guard usernameValid, emailValid, passwordValid else { return }
        let username = usernameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let email = emailField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let password = passwordField.text ?? ""
        enterBusy()
        Task {
            await self.performRegister(username: username, email: email, password: password)
        }
    }

    private func performRegister(username: String, email: String, password: String) async {
        let tabBar = tabBarController?.tabBar
        let navigationBar = navigationController?.navigationBar
        let popGesture = navigationController?.interactivePopGestureRecognizer
        defer {
            busyOverlay.hide()
            tabBar?.isUserInteractionEnabled = true
            navigationBar?.isUserInteractionEnabled = true
            popGesture?.isEnabled = true
        }
        do {
            try await session.register(username: username, email: email, password: password)
            onSuccess()
        } catch {
            showError(message(for: error))
        }
    }

    private func enterBusy() {
        errorLabel.isHidden = true
        view.endEditing(true)
        busyOverlay.show(in: view)
        tabBarController?.tabBar.isUserInteractionEnabled = false
        navigationController?.navigationBar.isUserInteractionEnabled = false
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    private func showError(_ text: String) {
        errorLabel.text = text
        errorLabel.isHidden = false
    }

    private func message(for error: SignUpError) -> String {
        switch error {
        case .noConnection:         return CoreStrings.errorNoConnection
        case .usernameOrEmailTaken: return CoreStrings.accountErrorTaken
        case .autoLoginFailed:      return CoreStrings.accountErrorGeneric
        case .unknown:              return CoreStrings.accountErrorGeneric
        }
    }
}
