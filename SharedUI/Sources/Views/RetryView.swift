import UIKit

public protocol RetryViewDelegate: AnyObject {
    func retryViewDidTapRetry(_ retryView: RetryView)
}

@MainActor
public final class RetryView: UIView {
    public weak var delegate: (any RetryViewDelegate)?

    private let messageLabel = UILabel()
    private let retryButton = PrimaryButton()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    public func configure(message: String, retryTitle: String = "Try again") {
        messageLabel.text = message
        retryButton.setTitle(retryTitle, for: .normal)
    }

    /// Stamps accessibility identifiers on this view and its retry button so UI tests
    /// can find both the container and the interactive control independently.
    public func setAccessibilityIdentifiers(container: String, button: String) {
        accessibilityIdentifier = container
        retryButton.accessibilityIdentifier = button
    }

    private func setupViews() {
        backgroundColor = SharedUIAsset.background.color

        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = SharedUIAsset.secondaryText.color

        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [messageLabel, retryButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: layoutMarginsGuide.trailingAnchor),
        ])
    }

    @objc private func retryTapped() {
        delegate?.retryViewDidTapRetry(self)
    }
}

#if DEBUG
import SwiftUI

#Preview("Retry — connection") {
    let view = RetryView(frame: CGRect(x: 0, y: 0, width: 375, height: 600))
    view.configure(message: "No internet connection. Check your network and try again.")
    return view
}

#Preview("Retry — generic") {
    let view = RetryView(frame: CGRect(x: 0, y: 0, width: 375, height: 600))
    view.configure(message: "Something went wrong loading the content. Please try again.")
    return view
}
#endif
