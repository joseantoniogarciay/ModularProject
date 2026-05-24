import UIKit

@MainActor
public struct ConfirmationDialogAction {
    public let title: String
    public let handler: (@MainActor () -> Void)?

    public init(title: String, handler: (@MainActor () -> Void)? = nil) {
        self.title = title
        self.handler = handler
    }
}

@MainActor
public struct ConfirmationDialogPayload {
    public var iconSystemName: String?
    public var iconImage: UIImage?
    public var iconTintColor: UIColor?
    public var title: String?
    public var message: String
    public var confirm: ConfirmationDialogAction
    public var cancel: ConfirmationDialogAction

    public init(
        iconSystemName: String? = nil,
        iconImage: UIImage? = nil,
        iconTintColor: UIColor? = nil,
        title: String? = nil,
        message: String,
        confirm: ConfirmationDialogAction,
        cancel: ConfirmationDialogAction
    ) {
        self.iconSystemName = iconSystemName
        self.iconImage = iconImage
        self.iconTintColor = iconTintColor
        self.title = title
        self.message = message
        self.confirm = confirm
        self.cancel = cancel
    }
}

@MainActor
public final class ConfirmationDialogViewController: UIViewController {
    private let payload: ConfirmationDialogPayload
    private let backgroundView = UIView()
    private let cardView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let confirmButton = PrimaryButton()
    private let cancelButton = OutlineButton()

    public init(payload: ConfirmationDialogPayload) {
        self.payload = payload
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupViews()
        configure()
    }

    private func setupViews() {
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        view.addSubview(backgroundView)
        backgroundView.pinEdges(to: view)

        let dimTap = UITapGestureRecognizer(target: self, action: #selector(cancelTapped))
        backgroundView.addGestureRecognizer(dimTap)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = SharedUIAsset.cardBackground.color
        cardView.layer.cornerRadius = 22
        cardView.layer.cornerCurve = .continuous
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.2
        cardView.layer.shadowOffset = CGSize(width: 0, height: 8)
        cardView.layer.shadowRadius = 24
        view.addSubview(cardView)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = SharedUIAsset.text.color
        iconImageView.isAccessibilityElement = false

        titleLabel.font = .preferredFont(forTextStyle: .title3)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.textColor = SharedUIAsset.text.color
        titleLabel.numberOfLines = 0

        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textAlignment = .center
        messageLabel.textColor = SharedUIAsset.secondaryText.color
        messageLabel.numberOfLines = 0

        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = 8

        let buttonStack = UIStackView(arrangedSubviews: [confirmButton, cancelButton])
        buttonStack.axis = .vertical
        buttonStack.alignment = .fill
        buttonStack.spacing = 12

        let contentStack = UIStackView(arrangedSubviews: [iconImageView, textStack, buttonStack])
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 20
        contentStack.setCustomSpacing(24, after: textStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            cardView.widthAnchor.constraint(lessThanOrEqualToConstant: 360),

            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 28),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),

            iconImageView.heightAnchor.constraint(equalToConstant: 56),
        ])
    }

    private func configure() {
        if let image = payload.iconImage {
            iconImageView.image = image
            iconImageView.isHidden = false
        } else if let name = payload.iconSystemName,
                  let symbol = UIImage(
                    systemName: name,
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 44, weight: .regular)
                  ) {
            iconImageView.image = symbol
            iconImageView.isHidden = false
        } else {
            iconImageView.isHidden = true
        }
        if let tint = payload.iconTintColor {
            iconImageView.tintColor = tint
        }

        if let title = payload.title, !title.isEmpty {
            titleLabel.text = title
            titleLabel.isHidden = false
        } else {
            titleLabel.isHidden = true
        }
        messageLabel.text = payload.message

        confirmButton.setTitle(payload.confirm.title, for: .normal)
        cancelButton.setTitle(payload.cancel.title, for: .normal)
    }

    @objc private func confirmTapped() {
        let handler = payload.confirm.handler
        dismiss(animated: true) {
            handler?()
        }
    }

    @objc private func cancelTapped() {
        let handler = payload.cancel.handler
        dismiss(animated: true) {
            handler?()
        }
    }
}

#if DEBUG
import SwiftUI

#Preview("ConfirmationDialog") {
    let host = UIViewController()
    host.view.backgroundColor = SharedUIAsset.background.color
    let dialog = ConfirmationDialogViewController(
        payload: ConfirmationDialogPayload(
            iconSystemName: "rectangle.portrait.and.arrow.right",
            iconTintColor: .systemRed,
            title: "Log out?",
            message: "You'll need to log in again to access your account.",
            confirm: ConfirmationDialogAction(title: "Log out"),
            cancel: ConfirmationDialogAction(title: "Cancel")
        )
    )
    DispatchQueue.main.async {
        host.present(dialog, animated: false)
    }
    return host
}
#endif
