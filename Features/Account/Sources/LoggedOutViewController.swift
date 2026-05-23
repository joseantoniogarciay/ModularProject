import Core
import SharedUI
import UIKit

@MainActor
final class LoggedOutViewController: UIViewController {
    private let session: any AuthSession
    private weak var navigator: (any AccountNavigator)?

    private let scrollView = KeyboardAvoidingScrollView()
    private let contentView = UIView()

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
    private let loginButton = UIButton(type: .system)
    private let registerButton = UIButton(type: .system)
    private let errorLabel = UILabel()
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
        view.backgroundColor = CoreAsset.background.color
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
        subtitleLabel.textColor = CoreAsset.secondaryText.color
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

        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel,
            identifierField,
            passwordField,
            loginButton,
            errorLabel,
            registerButton,
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        configureLayout(stack: stack)
    }

    private func configureLayout(stack: UIStackView) {
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
            contentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor),

            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
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
        errorLabel.isHidden = true
        view.endEditing(true)
        busyOverlay.show(in: view)
        tabBarController?.tabBar.isUserInteractionEnabled = false
    }

    private func showError(_ text: String) {
        errorLabel.text = text
        errorLabel.isHidden = false
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
