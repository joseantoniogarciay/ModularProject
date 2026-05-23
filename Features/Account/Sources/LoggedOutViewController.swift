import Core
import SharedUI
import UIKit

@MainActor
final class LoggedOutViewController: UIViewController {
    private let session: any AuthSession
    private weak var navigator: (any AccountNavigator)?

    private let scrollView = KeyboardAvoidingScrollView()
    private let contentView = UIView()

    private let logoView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let identifierField = ValidatedTextField(
        placeholder: CoreStrings.accountUsernameOrEmailPlaceholder,
        validators: [TextFieldValidators.notEmpty(CoreStrings.accountErrorFieldRequired)]
    )
    private let passwordField = ValidatedTextField(
        placeholder: CoreStrings.accountPasswordPlaceholder,
        validators: [TextFieldValidators.notEmpty(CoreStrings.accountErrorFieldRequired)]
    )
    private let loginButton = PrimaryButton()
    private let registerButton = TextLinkButton()
    private let busyOverlay = BusyOverlay()

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
        view.backgroundColor = SharedUIAsset.background.color
        scrollView.backgroundColor = SharedUIAsset.background.color
        configureViews()
    }

    private func configureViews() {
        logoView.image = SharedUIAsset.logo.image
        logoView.contentMode = .scaleAspectFit
        logoView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = CoreStrings.accountLoggedOutTitle
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = SharedUIAsset.text.color
        titleLabel.textAlignment = .center

        subtitleLabel.text = CoreStrings.accountLoggedOutSubtitle
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = SharedUIAsset.secondaryText.color
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        identifierField.textField.textContentType = .username
        identifierField.textField.autocapitalizationType = .none
        identifierField.textField.autocorrectionType = .no
        identifierField.textField.returnKeyType = .next
        identifierField.textField.delegate = self

        passwordField.textField.isSecureTextEntry = true
        passwordField.textField.textContentType = .password
        passwordField.textField.returnKeyType = .done
        passwordField.textField.delegate = self

        loginButton.setTitle(CoreStrings.accountLoginButton, for: .normal)
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)

        registerButton.setTitle(CoreStrings.accountRegisterButton, for: .normal)
        registerButton.addTarget(self, action: #selector(registerTapped), for: .touchUpInside)

        let headerStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 8
        headerStack.alignment = .center

        let fieldStack = UIStackView(arrangedSubviews: [identifierField, passwordField])
        fieldStack.axis = .vertical
        fieldStack.spacing = 8
        fieldStack.alignment = .fill

        let registerRow = UIStackView(arrangedSubviews: [registerButton])
        registerRow.axis = .vertical
        registerRow.alignment = .trailing

        let actionStack = UIStackView(arrangedSubviews: [loginButton, registerRow])
        actionStack.axis = .vertical
        actionStack.alignment = .fill
        actionStack.setCustomSpacing(24, after: loginButton)

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
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor),

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

    @objc private func loginTapped() {
        let identifierValid = identifierField.validate()
        let passwordValid = passwordField.validate()
        guard identifierValid, passwordValid else { return }
        let identifier = identifierField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let password = passwordField.text ?? ""
        enterBusy()
        Task {
            await self.performLogin(identifier: identifier, password: password)
        }
    }

    private func performLogin(identifier: String, password: String) async {
        let tabBar = tabBarController?.tabBar
        defer {
            busyOverlay.hide()
            tabBar?.isUserInteractionEnabled = true
        }
        do {
            try await session.login(identifier: identifier, password: password)
        } catch {
            showError(message(for: error))
        }
    }

    @objc private func registerTapped() {
        navigator?.accountDidRequestRegister()
    }

    private func enterBusy() {
        view.endEditing(true)
        busyOverlay.show(in: view)
        tabBarController?.tabBar.isUserInteractionEnabled = false
    }

    private func showError(_ text: String) {
        BannerCenter.shared.show(BannerPayload(message: text, style: .error))
    }

    private func message(for error: LoginError) -> String {
        switch error {
        case .noConnection:        return CoreStrings.errorNoConnection
        case .invalidCredentials:  return CoreStrings.accountErrorInvalidCredentials
        case .unknown:             return CoreStrings.accountErrorGeneric
        }
    }
}

extension LoggedOutViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === identifierField.textField {
            passwordField.textField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}

#if DEBUG
import SwiftUI

#Preview("Logged Out") {
    LoggedOutViewController(
        session: PreviewAuthSession(),
        navigator: nil
    )
}
#endif
