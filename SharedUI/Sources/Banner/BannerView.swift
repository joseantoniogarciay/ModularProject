import UIKit

@MainActor
public struct BannerPayload {
    public var title: String?
    public var message: String
    public var style: BannerStyle
    public var iconSystemName: String?
    public var duration: TimeInterval
    public var onTap: (@MainActor () -> Void)?

    public init(
        title: String? = nil,
        message: String,
        style: BannerStyle = .info,
        iconSystemName: String? = nil,
        duration: TimeInterval = 4,
        onTap: (@MainActor () -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.style = style
        self.iconSystemName = iconSystemName
        self.duration = duration
        self.onTap = onTap
    }
}

@MainActor
public struct BannerStyle {
    public let backgroundColor: UIColor
    public let foregroundColor: UIColor
    public let secondaryForegroundColor: UIColor

    public init(
        backgroundColor: UIColor,
        foregroundColor: UIColor,
        secondaryForegroundColor: UIColor
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.secondaryForegroundColor = secondaryForegroundColor
    }

    public static let info = BannerStyle(
        backgroundColor: SharedUIAsset.bannerInfoBackground.color,
        foregroundColor: SharedUIAsset.text.color,
        secondaryForegroundColor: SharedUIAsset.secondaryText.color
    )

    public static let warning = BannerStyle(
        backgroundColor: SharedUIAsset.bannerWarningBackground.color,
        foregroundColor: SharedUIAsset.bannerWarningForeground.color,
        secondaryForegroundColor: SharedUIAsset.bannerWarningForeground.color.withAlphaComponent(0.7)
    )

    public static let error = BannerStyle(
        backgroundColor: SharedUIAsset.bannerErrorBackground.color,
        foregroundColor: SharedUIAsset.bannerErrorForeground.color,
        secondaryForegroundColor: SharedUIAsset.bannerErrorForeground.color.withAlphaComponent(0.75)
    )
}

@MainActor
public final class BannerView: UIView {
    private let cardView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()

    private var onTap: (() -> Void)?
    var onDismiss: (() -> Void)?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupGestures()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
    }

    public func configure(with payload: BannerPayload) {
        cardView.backgroundColor = payload.style.backgroundColor
        titleLabel.textColor = payload.style.foregroundColor
        messageLabel.textColor = payload.style.secondaryForegroundColor
        iconImageView.tintColor = payload.style.foregroundColor

        if let title = payload.title, !title.isEmpty {
            titleLabel.text = title
            titleLabel.isHidden = false
        } else {
            titleLabel.text = nil
            titleLabel.isHidden = true
        }
        messageLabel.text = payload.message

        if let iconName = payload.iconSystemName, let image = UIImage(systemName: iconName) {
            iconImageView.image = image
            iconImageView.isHidden = false
        } else {
            iconImageView.image = nil
            iconImageView.isHidden = true
        }

        onTap = payload.onTap
    }

    private func setupViews() {
        backgroundColor = .clear

        layer.shadowColor = UIColor.label.resolvedColor(with: traitCollection).cgColor
        layer.shadowOpacity = 0.18
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: BannerView, _) in
            self.layer.shadowColor = UIColor.label.resolvedColor(with: self.traitCollection).cgColor
        }

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.layer.cornerRadius = 16
        cardView.layer.cornerCurve = .continuous
        cardView.clipsToBounds = true
        addSubview(cardView)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.isHidden = true

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 1
        titleLabel.isHidden = true

        messageLabel.font = .preferredFont(forTextStyle: .footnote)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .fill

        let contentStack = UIStackView(arrangedSubviews: [iconImageView, textStack])
        contentStack.axis = .horizontal
        contentStack.spacing = 12
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: topAnchor),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            iconImageView.widthAnchor.constraint(equalToConstant: 28),
            iconImageView.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)

        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeUp))
        swipeUp.direction = .up
        addGestureRecognizer(swipeUp)
    }

    @objc private func handleTap() {
        let handler = onTap
        onDismiss?()
        handler?()
    }

    @objc private func handleSwipeUp() {
        onDismiss?()
    }
}

#if DEBUG
import SwiftUI

#Preview("Banner — warning") {
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 200))
    view.backgroundColor = .systemBackground
    let banner = BannerView()
    banner.translatesAutoresizingMaskIntoConstraints = false
    banner.configure(
        with: BannerPayload(
            message: "Your session expired. Please log in again.",
            style: .warning,
            iconSystemName: "exclamationmark.triangle.fill"
        )
    )
    view.addSubview(banner)
    NSLayoutConstraint.activate([
        banner.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
        banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
        banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
    ])
    return view
}
#endif
