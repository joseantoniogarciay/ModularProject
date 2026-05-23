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
    private let emailValueLabel = UILabel()
    private let roleValueLabel = UILabel()
    private let idValueLabel = UILabel()
    private let cardView = UIView()
    private let cartButton = PrimaryButton()

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
        view.backgroundColor = SharedUIAsset.background.color
        configureViews()
        updateCardAppearance()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: LoggedInViewController, _: UITraitCollection) in
            self?.updateCardAppearance()
        }
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
        greetingLabel.font = .preferredFont(forTextStyle: .largeTitle)
        greetingLabel.adjustsFontForContentSizeCategory = true
        greetingLabel.textColor = SharedUIAsset.text.color
        greetingLabel.numberOfLines = 0

        cardView.backgroundColor = SharedUIAsset.cardBackground.color
        cardView.layer.cornerRadius = 14
        cardView.layer.cornerCurve = .continuous
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowRadius = 10
        cardView.layer.shadowOffset = CGSize(width: 0, height: 3)
        cardView.translatesAutoresizingMaskIntoConstraints = false

        let cardStack = UIStackView(arrangedSubviews: [
            makeInfoRow(label: CoreStrings.accountProfileEmailLabel, valueLabel: emailValueLabel),
            makeSeparator(),
            makeInfoRow(label: CoreStrings.accountProfileRoleLabel, valueLabel: roleValueLabel),
            makeSeparator(),
            makeInfoRow(label: CoreStrings.accountProfileIdLabel, valueLabel: idValueLabel),
        ])
        cardStack.axis = .vertical
        cardStack.spacing = 12
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(cardStack)

        cartButton.setTitle(CoreStrings.accountCartButton, for: .normal)
        cartButton.addTarget(self, action: #selector(cartTapped), for: .touchUpInside)

        let mainStack = UIStackView(arrangedSubviews: [greetingLabel, cardView, cartButton])
        mainStack.axis = .vertical
        mainStack.alignment = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.setCustomSpacing(24, after: greetingLabel)
        mainStack.setCustomSpacing(32, after: cardView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
        contentView.addSubview(mainStack)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
            mainStack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -32),

            cardStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            cardStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            cardStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),
        ])
    }

    private func makeInfoRow(label: String, valueLabel: UILabel) -> UIStackView {
        let captionLabel = UILabel()
        captionLabel.text = label
        captionLabel.font = .preferredFont(forTextStyle: .caption1)
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.textColor = SharedUIAsset.secondaryText.color

        valueLabel.font = .preferredFont(forTextStyle: .body)
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.textColor = SharedUIAsset.text.color
        valueLabel.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [captionLabel, valueLabel])
        row.axis = .vertical
        row.spacing = 2
        return row
    }

    private func makeSeparator() -> UIView {
        let sep = UIView()
        sep.backgroundColor = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return sep
    }

    private func updateCardAppearance() {
        if traitCollection.userInterfaceStyle == .dark {
            cardView.layer.shadowOpacity = 0
            cardView.layer.borderWidth = 0.5
            cardView.layer.borderColor = UIColor(white: 1.0, alpha: 0.14).cgColor
        } else {
            cardView.layer.shadowOpacity = 0.09
            cardView.layer.borderWidth = 0
        }
    }

    private func bind(to user: User) {
        greetingLabel.text = CoreStrings.accountGreetingFormat(user.username)
        emailValueLabel.text = user.email
        roleValueLabel.text = user.role ?? "-"
        idValueLabel.text = user.id
    }

    @objc private func cartTapped() {
        navigator?.accountDidRequestCart()
    }
}

#if DEBUG
import SwiftUI

#Preview("Logged In") {
    let user = User(id: "42", username: "sara", email: "sara@example.com", role: "admin", avatarURL: nil)
    return UINavigationController(
        rootViewController: LoggedInViewController(
            session: PreviewAuthSession(),
            user: user,
            navigator: nil
        )
    )
}
#endif
