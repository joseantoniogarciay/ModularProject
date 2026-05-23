import Core
import SharedUI
import UIKit

@MainActor
final class RegisterViewController: UIViewController {
    private let session: any AuthSession
    private let onSuccess: () -> Void

    private let scrollView = KeyboardAvoidingScrollView()
    private let contentView = UIView()

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
        usernameField.textField.returnKeyType = .next
        usernameField.textField.delegate = self

        emailField.textField.keyboardType = .emailAddress
        emailField.textField.textContentType = .emailAddress
        emailField.textField.autocapitalizationType = .none
        emailField.textField.autocorrectionType = .no
        emailField.textField.returnKeyType = .next
        emailField.textField.delegate = self

        passwordField.textField.isSecureTextEntry = true
        passwordField.textField.textContentType = .newPassword
        passwordField.textField.returnKeyType = .done
        passwordField.textField.delegate = self

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

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
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

extension RegisterViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === usernameField.textField {
            emailField.textField.becomeFirstResponder()
        } else if textField === emailField.textField {
            passwordField.textField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}

#if DEBUG
import SwiftUI

#Preview("Register") {
    UINavigationController(
        rootViewController: RegisterViewController(
            session: PreviewAuthSession(),
            onSuccess: {}
        )
    )
}
#endif
