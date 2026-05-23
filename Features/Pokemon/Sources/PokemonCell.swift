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
        UIView.animate(withDuration: 0.12) {
            self.cardView.alpha = highlighted ? 0.75 : 1.0
            self.cardView.transform = highlighted
                ? CGAffineTransform(scaleX: 0.97, y: 0.97)
                : .identity
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
        cardView.backgroundColor = .secondarySystemBackground
        cardView.layer.cornerRadius = 14
        cardView.layer.cornerCurve = .continuous
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowRadius = 10
        cardView.layer.shadowOffset = CGSize(width: 0, height: 3)

        spriteImageView.contentMode = .scaleAspectFit
        spriteImageView.tintColor = CoreAsset.secondaryText.color
        spriteImageView.pinSize(72)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .preferredFont(forTextStyle: .headline)
        nameLabel.adjustsFontForContentSizeCategory = true

        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        numberLabel.font = .preferredFont(forTextStyle: .caption1)
        numberLabel.textColor = CoreAsset.secondaryText.color
        numberLabel.adjustsFontForContentSizeCategory = true

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = CoreAsset.secondaryText.color
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .caption1)
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        contentView.addSubview(cardView)
        cardView.addSubview(spriteImageView)
        cardView.addSubview(nameLabel)
        cardView.addSubview(numberLabel)
        cardView.addSubview(chevron)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            spriteImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            spriteImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            spriteImageView.topAnchor.constraint(greaterThanOrEqualTo: cardView.topAnchor, constant: 12),
            spriteImageView.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -12),

            nameLabel.leadingAnchor.constraint(equalTo: spriteImageView.trailingAnchor, constant: 14),
            nameLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            nameLabel.bottomAnchor.constraint(equalTo: cardView.centerYAnchor, constant: -1),

            numberLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            numberLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            numberLabel.topAnchor.constraint(equalTo: cardView.centerYAnchor, constant: 2),

            chevron.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
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
