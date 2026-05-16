import Core
import Kingfisher
import SharedUI
import UIKit

final class PokemonCell: UITableViewCell {
    static let reuseID = "PokemonCell"

    private let spriteImageView = UIImageView()
    private let nameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func configure(with pokemon: Pokemon) {
        nameLabel.text = pokemon.name.capitalized
        spriteImageView.kf.setImage(
            with: pokemon.imageURL,
            placeholder: UIImage(systemName: "photo")
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        spriteImageView.kf.cancelDownloadTask()
        spriteImageView.image = nil
        nameLabel.text = nil
    }

    private func setupViews() {
        accessoryType = .disclosureIndicator

        spriteImageView.contentMode = .scaleAspectFit
        spriteImageView.tintColor = .secondaryLabel
        spriteImageView.pinSize(60)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .preferredFont(forTextStyle: .body)
        nameLabel.adjustsFontForContentSizeCategory = true

        contentView.addSubview(spriteImageView)
        contentView.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            spriteImageView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            spriteImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 72),

            nameLabel.leadingAnchor.constraint(equalTo: spriteImageView.trailingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
}
