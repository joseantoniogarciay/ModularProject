import Core
import SharedUI
import UIKit

final class PokemonCell: UITableViewCell {
    static let reuseID = "PokemonCell"

    private let cardView = UIView()
    private let spriteImageView = UIImageView()
    private let nameLabel = UILabel()
    private let numberLabel = UILabel()
    private var imageLoader: (any ImageLoader)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        updateCardAppearance()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: PokemonCell, _: UITraitCollection) in
            self?.updateCardAppearance()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func configure(with pokemon: Pokemon, imageLoader: any ImageLoader) {
        self.imageLoader = imageLoader
        nameLabel.text = pokemon.name.capitalized
        numberLabel.text = String(format: "#%03d", pokemon.id)
        imageLoader.setImage(
            pokemon.imageURL,
            placeholder: UIImage(systemName: "photo"),
            on: spriteImageView
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageLoader?.cancel(on: spriteImageView)
        imageLoader = nil
        spriteImageView.image = nil
        nameLabel.text = nil
        numberLabel.text = nil
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        let apply = {
            self.cardView.alpha = highlighted ? 0.75 : 1.0
            self.cardView.transform = highlighted
                ? CGAffineTransform(scaleX: 0.97, y: 0.97)
                : .identity
        }
        if animated, !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.12, animations: apply)
        } else {
            apply()
        }
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

    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = SharedUIAsset.cardBackground.color
        cardView.layer.cornerRadius = 14
        cardView.layer.cornerCurve = .continuous
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowRadius = 10
        cardView.layer.shadowOffset = CGSize(width: 0, height: 3)

        spriteImageView.contentMode = .scaleAspectFit
        spriteImageView.tintColor = SharedUIAsset.secondaryText.color
        spriteImageView.isAccessibilityElement = false
        spriteImageView.pinSize(72)

        // numberOfLines = 0 lets the name wrap at large content sizes instead of clipping.
        nameLabel.font = .preferredFont(forTextStyle: .headline)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 0

        numberLabel.font = .preferredFont(forTextStyle: .caption1)
        numberLabel.textColor = SharedUIAsset.secondaryText.color
        numberLabel.adjustsFontForContentSizeCategory = true

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = SharedUIAsset.secondaryText.color
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .caption1)
        chevron.isAccessibilityElement = false
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        // Vertical stack for name + number — grows naturally with Dynamic Type.
        let textStack = UIStackView(arrangedSubviews: [nameLabel, numberLabel])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        // Horizontal stack: [sprite | textStack | chevron], all centered on the same axis.
        // UIStackView.alignment = .center keeps the sprite and chevron mid-aligned as text grows.
        let outerStack = UIStackView(arrangedSubviews: [spriteImageView, textStack, chevron])
        outerStack.axis = .horizontal
        outerStack.alignment = .center
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.setCustomSpacing(14, after: spriteImageView)
        outerStack.setCustomSpacing(8, after: textStack)

        contentView.addSubview(cardView)
        cardView.addSubview(outerStack)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            outerStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            outerStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            outerStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            outerStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
        ])
    }
}

#if DEBUG
import SwiftUI

#Preview("Pokemon Cell") {
    let cell = PokemonCell(style: .default, reuseIdentifier: nil)
    cell.configure(
        with: Pokemon(
            id: 25,
            name: "Pikachu",
            imageURL: URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/25.png")
        ),
        imageLoader: PreviewImageLoader()
    )
    return CellPreview(cell, height: 108)
}
#endif
