import Core
import SharedUI
import UIKit

final class CartItemCell: UITableViewCell {
    static let reuseID = "CartItemCell"

    private let nameLabel = UILabel()
    private let detailLabel = UILabel()
    private let subtotalLabel = UILabel()

    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func configure(with item: CartItem) {
        nameLabel.text = item.productName
        let unit = Self.priceFormatter.string(from: NSNumber(value: item.unitPrice))
            ?? String(format: "%.2f", item.unitPrice)
        detailLabel.text = CoreStrings.cartItemDetailFormat(unit, item.quantity)
        let subtotal = item.unitPrice * Double(item.quantity)
        subtotalLabel.text = Self.priceFormatter.string(from: NSNumber(value: subtotal))
            ?? String(format: "%.2f", subtotal)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        detailLabel.text = nil
        subtotalLabel.text = nil
    }

    private func setupViews() {
        accessoryType = .none
        selectionStyle = .none
        backgroundColor = .clear

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .preferredFont(forTextStyle: .headline)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 0

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = SharedUIAsset.secondaryText.color

        subtotalLabel.translatesAutoresizingMaskIntoConstraints = false
        subtotalLabel.font = .preferredFont(forTextStyle: .headline)
        subtotalLabel.adjustsFontForContentSizeCategory = true
        subtotalLabel.textAlignment = .right
        subtotalLabel.setContentHuggingPriority(.required, for: .horizontal)
        subtotalLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(textStack)
        contentView.addSubview(subtotalLabel)

        NSLayoutConstraint.activate([
            textStack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            textStack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            textStack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),

            subtotalLabel.leadingAnchor.constraint(greaterThanOrEqualTo: textStack.trailingAnchor, constant: 12),
            subtotalLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            subtotalLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
}

#if DEBUG
import SwiftUI

#Preview("Cart Item Cell") {
    let cell = CartItemCell(style: .default, reuseIdentifier: nil)
    cell.configure(
        with: CartItem(
            id: "abc",
            productId: "p1",
            productName: "Wireless Headphones",
            unitPrice: 89.99,
            quantity: 2
        )
    )
    return CellPreview(cell, height: 80)
}
#endif
