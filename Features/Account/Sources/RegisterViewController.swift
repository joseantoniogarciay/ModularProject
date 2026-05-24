import Core
import SharedUI
import UIKit

@MainActor
final class RegisterViewController: UIViewController {
    private let session: any AuthSession
    private let onSuccess: () -> Void

    private let scrollView = KeyboardAvoidingScrollView()
    private let contentView = UIView()

    private let logoView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
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
    private let registerButton = PrimaryButton()

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
        view.backgroundColor = SharedUIAsset.background.color
        scrollView.backgroundColor = SharedUIAsset.background.color
        configureViews()
    }

    private func configureViews() {
        logoView.image = SharedUIAsset.logo.image
        logoView.contentMode = .scaleAspectFit
        logoView.isAccessibilityElement = false
        logoView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = CoreStrings.accountRegisterScreenTitle
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = SharedUIAsset.text.color
        titleLabel.textAlignment = .center

        subtitleLabel.text = CoreStrings.accountRegisterSubtitle
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = SharedUIAsset.secondaryText.color
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

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
        registerButton.addTarget(self, action: #selector(registerTapped), for: .touchUpInside)

        let headerStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 8
        headerStack.alignment = .center

        let fieldStack = UIStackView(arrangedSubviews: [usernameField, emailField, passwordField])
        fieldStack.axis = .vertical
        fieldStack.spacing = 8
        fieldStack.alignment = .fill

        let actionStack = UIStackView(arrangedSubviews: [registerButton])
        actionStack.axis = .vertical
        actionStack.alignment = .fill

        let mainStack = UIStackView(arrangedSubviews: [headerStack, fieldStack, actionStack])
        mainStack.axis = .vertical
        mainStack.alignment = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.setCustomSpacing(32, after: headerStack)
        mainStack.setCustomSpacing(24, after: fieldStack)

        configureLayout(logo: logoView, stack: mainStack)
    }

    private func configureLayout(logo: UIImageView, stack: UIStackView) {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
        contentView.addSubview(logo)
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
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.safeAreaLayoutGuide.heightAnchor),

            logo.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logo.widthAnchor.constraint(equalToConstant: 64),
            logo.heightAnchor.constraint(equalToConstant: 64),
            logo.bottomAnchor.constraint(equalTo: stack.topAnchor, constant: -40),

            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 40),
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -40),
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
            registerButton.isLoading = false
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
        view.endEditing(true)
        registerButton.isLoading = true
        tabBarController?.tabBar.isUserInteractionEnabled = false
        navigationController?.navigationBar.isUserInteractionEnabled = false
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    private func showError(_ text: String) {
        BannerCenter.shared.show(BannerPayload(message: text, style: .error))
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
