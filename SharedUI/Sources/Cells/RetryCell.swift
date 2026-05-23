import UIKit

public final class RetryCell: UITableViewCell {
    public static let reuseID = "RetryCell"

    private let messageLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private var onRetry: (@MainActor () -> Void)?

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        onRetry = nil
        messageLabel.text = nil
    }

    public func configure(message: String, retryTitle: String, onRetry: @escaping @MainActor () -> Void) {
        messageLabel.text = message
        retryButton.setTitle(retryTitle, for: .normal)
        self.onRetry = onRetry
    }

    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear

        messageLabel.font = .preferredFont(forTextStyle: .footnote)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        retryButton.titleLabel?.font = .preferredFont(forTextStyle: .footnote)
        retryButton.titleLabel?.adjustsFontForContentSizeCategory = true
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [messageLabel, retryButton])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
        ])
    }

    @objc private func retryTapped() {
        onRetry?()
    }
}

#if DEBUG
import SwiftUI

#Preview("RetryCell — connection") {
    let cell = RetryCell(style: .default, reuseIdentifier: nil)
    cell.configure(
        message: "No internet connection.",
        retryTitle: "Try again",
        onRetry: {}
    )
    return CellPreview(cell, height: 80)
}
#endif
