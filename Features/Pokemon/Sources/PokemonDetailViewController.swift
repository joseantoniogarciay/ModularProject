import Core
import SharedUI
import UIKit

@MainActor
public final class PokemonDetailViewController: UIViewController {
    private let repository: any PokemonRepository
    private let pokemon: Pokemon
    private let imageLoader: any ImageLoader

    private var loadTask: Task<Void, Never>?

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let spriteImageView = UIImageView()
    private let typesWrapperView = UIView()
    private let typesStackView = UIStackView()
    private let metricsRowView = UIStackView()
    private let statsHeaderLabel = UILabel()
    private let statsStackView = UIStackView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let retryView = RetryView()

    public init(
        repository: any PokemonRepository,
        pokemon: Pokemon,
        imageLoader: any ImageLoader
    ) {
        self.repository = repository
        self.pokemon = pokemon
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    deinit {
        loadTask?.cancel()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = CoreAsset.background.color
        title = pokemon.name.capitalized
        setupUI()
        showInitial()
        loadDetail()
    }

    private func setupUI() {
        scrollView.backgroundColor = CoreAsset.background.color
        view.addSubview(scrollView)
        scrollView.pinEdges(to: view)

        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 32, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        scrollView.addSubview(stackView)
        stackView.pinEdges(to: scrollView)
        stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true

        spriteImageView.contentMode = .scaleAspectFit
        spriteImageView.tintColor = CoreAsset.secondaryText.color
        spriteImageView.translatesAutoresizingMaskIntoConstraints = false
        spriteImageView.heightAnchor.constraint(equalToConstant: 200).isActive = true
        stackView.addArrangedSubview(spriteImageView)

        typesStackView.axis = .horizontal
        typesStackView.spacing = 8
        typesStackView.alignment = .center
        typesStackView.translatesAutoresizingMaskIntoConstraints = false
        typesWrapperView.translatesAutoresizingMaskIntoConstraints = false
        typesWrapperView.addSubview(typesStackView)
        NSLayoutConstraint.activate([
            typesStackView.topAnchor.constraint(equalTo: typesWrapperView.topAnchor),
            typesStackView.bottomAnchor.constraint(equalTo: typesWrapperView.bottomAnchor),
            typesStackView.centerXAnchor.constraint(equalTo: typesWrapperView.centerXAnchor),
            typesStackView.leadingAnchor.constraint(greaterThanOrEqualTo: typesWrapperView.leadingAnchor),
        ])
        stackView.addArrangedSubview(typesWrapperView)

        metricsRowView.axis = .horizontal
        metricsRowView.spacing = 12
        metricsRowView.distribution = .fillEqually
        stackView.addArrangedSubview(metricsRowView)

        statsHeaderLabel.text = "Base Stats"
        statsHeaderLabel.font = .preferredFont(forTextStyle: .headline)
        statsHeaderLabel.adjustsFontForContentSizeCategory = true
        stackView.addArrangedSubview(statsHeaderLabel)
        stackView.setCustomSpacing(10, after: statsHeaderLabel)

        statsStackView.axis = .vertical
        statsStackView.spacing = 10
        statsStackView.alignment = .fill
        stackView.addArrangedSubview(statsStackView)

        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()
        stackView.addArrangedSubview(activityIndicator)

        retryView.delegate = self
        retryView.isHidden = true
        view.addSubview(retryView)
        retryView.pinEdges(to: view)
    }

    private func showInitial() {
        imageLoader.setImage(
            pokemon.imageURL,
            placeholder: UIImage(systemName: "photo"),
            on: spriteImageView
        )
        typesWrapperView.isHidden = true
        metricsRowView.isHidden = true
        statsHeaderLabel.isHidden = true
        statsStackView.isHidden = true
    }

    private func loadDetail() {
        scrollView.isHidden = false
        retryView.isHidden = true
        activityIndicator.startAnimating()
        loadTask = Task {
            await self.performLoad()
        }
    }

    private func performLoad() async {
        defer { loadTask = nil }
        do {
            let detail = try await repository.detail(id: pokemon.id)
            guard !Task.isCancelled else { return }
            render(detail)
        } catch {
            guard !Task.isCancelled else { return }
            handleLoadError(error)
        }
    }

    private func render(_ detail: PokemonDetail) {
        if let url = detail.imageURL {
            imageLoader.setImage(url, placeholder: spriteImageView.image, on: spriteImageView)
        }

        typesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for type in detail.types {
            typesStackView.addArrangedSubview(makeTypeBadge(type))
        }
        typesWrapperView.isHidden = false

        metricsRowView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let heightM = Double(detail.heightDecimetres) / 10.0
        let weightKg = Double(detail.weightHectograms) / 10.0
        metricsRowView.addArrangedSubview(
            makeMetricCard(title: "Height", value: String(format: "%.1f m", heightM), icon: "ruler")
        )
        metricsRowView.addArrangedSubview(
            makeMetricCard(title: "Weight", value: String(format: "%.1f kg", weightKg), icon: "scalemass")
        )
        metricsRowView.isHidden = false

        statsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for stat in detail.stats {
            statsStackView.addArrangedSubview(makeStatRow(stat))
        }
        statsHeaderLabel.isHidden = false
        statsStackView.isHidden = false

        activityIndicator.stopAnimating()
    }

    private func handleLoadError(_ error: PokemonDetailError) {
        activityIndicator.stopAnimating()
        retryView.configure(
            message: messageFor(error),
            retryTitle: CoreStrings.retryButtonTitle
        )
        scrollView.isHidden = true
        retryView.isHidden = false
    }

    private func messageFor(_ error: PokemonDetailError) -> String {
        switch error {
        case .noConnection: return CoreStrings.errorNoConnection
        case .unknown:      return CoreStrings.errorGenericLoading
        }
    }
}

// MARK: - RetryViewDelegate

extension PokemonDetailViewController: RetryViewDelegate {
    public func retryViewDidTapRetry(_ retryView: RetryView) {
        loadDetail()
    }
}

// MARK: - View factories

private extension PokemonDetailViewController {
    func makeTypeBadge(_ type: String) -> UIView {
        let badge = UIView()
        badge.backgroundColor = typeColor(for: type)
        badge.layer.cornerRadius = 10
        badge.layer.cornerCurve = .continuous

        let label = UILabel()
        label.text = type.capitalized
        let base = UIFont.systemFont(ofSize: 12, weight: .semibold)
        label.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: base)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false

        badge.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: badge.topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -5),
            label.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -12),
        ])
        return badge
    }

    func makeMetricCard(title: String, value: String, icon: String) -> UIView {
        let card = UIView()
        card.backgroundColor = CoreAsset.cardBackground.color
        card.layer.cornerRadius = 12
        card.layer.cornerCurve = .continuous

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = CoreAsset.secondaryText.color
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .preferredFont(forTextStyle: .headline)
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.textAlignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .caption1)
        titleLabel.textColor = CoreAsset.secondaryText.color
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let vStack = UIStackView(arrangedSubviews: [iconView, valueLabel, titleLabel])
        vStack.axis = .vertical
        vStack.alignment = .center
        vStack.spacing = 4
        vStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(vStack)
        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            vStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            vStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            vStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
        ])
        return card
    }

    func makeStatRow(_ stat: PokemonStat) -> UIView {
        let nameLabel = UILabel()
        nameLabel.text = displayName(for: stat.name)
        nameLabel.font = .preferredFont(forTextStyle: .caption1)
        nameLabel.textColor = CoreAsset.secondaryText.color
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.widthAnchor.constraint(equalToConstant: 68).isActive = true

        let valueLabel = UILabel()
        valueLabel.text = "\(stat.baseValue)"
        valueLabel.font = .preferredFont(forTextStyle: .caption1)
        valueLabel.textColor = CoreAsset.secondaryText.color
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.widthAnchor.constraint(equalToConstant: 30).isActive = true

        let trackView = UIView()
        trackView.backgroundColor = CoreAsset.statTrack.color
        trackView.layer.cornerRadius = 3
        trackView.translatesAutoresizingMaskIntoConstraints = false

        let fillView = UIView()
        fillView.backgroundColor = barColor(for: stat.baseValue)
        fillView.layer.cornerRadius = 3
        fillView.translatesAutoresizingMaskIntoConstraints = false
        trackView.addSubview(fillView)

        let ratio = max(0.01, min(CGFloat(stat.baseValue) / 255.0, 1.0))
        NSLayoutConstraint.activate([
            fillView.topAnchor.constraint(equalTo: trackView.topAnchor),
            fillView.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),
            fillView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            fillView.widthAnchor.constraint(equalTo: trackView.widthAnchor, multiplier: ratio),
            trackView.heightAnchor.constraint(equalToConstant: 6),
        ])

        let row = UIStackView(arrangedSubviews: [nameLabel, trackView, valueLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        return row
    }
}

// MARK: - Helpers

private extension PokemonDetailViewController {
    static let typeColors: [String: UIColor] = [
        "fire": UIColor(red: 0.98, green: 0.42, blue: 0.21, alpha: 1),
        "water": UIColor(red: 0.24, green: 0.56, blue: 0.90, alpha: 1),
        "grass": UIColor(red: 0.32, green: 0.72, blue: 0.30, alpha: 1),
        "electric": UIColor(red: 0.95, green: 0.72, blue: 0.10, alpha: 1),
        "psychic": UIColor(red: 0.95, green: 0.29, blue: 0.52, alpha: 1),
        "ice": UIColor(red: 0.44, green: 0.74, blue: 0.83, alpha: 1),
        "dragon": UIColor(red: 0.44, green: 0.20, blue: 0.95, alpha: 1),
        "dark": UIColor(red: 0.44, green: 0.35, blue: 0.29, alpha: 1),
        "fairy": UIColor(red: 0.90, green: 0.55, blue: 0.72, alpha: 1),
        "fighting": UIColor(red: 0.75, green: 0.19, blue: 0.15, alpha: 1),
        "poison": UIColor(red: 0.63, green: 0.25, blue: 0.63, alpha: 1),
        "ground": UIColor(red: 0.88, green: 0.72, blue: 0.35, alpha: 1),
        "rock": UIColor(red: 0.71, green: 0.63, blue: 0.37, alpha: 1),
        "bug": UIColor(red: 0.59, green: 0.67, blue: 0.08, alpha: 1),
        "ghost": UIColor(red: 0.44, green: 0.35, blue: 0.62, alpha: 1),
        "steel": UIColor(red: 0.60, green: 0.62, blue: 0.70, alpha: 1),
        "normal": UIColor(red: 0.66, green: 0.65, blue: 0.48, alpha: 1),
        "flying": UIColor(red: 0.55, green: 0.53, blue: 0.90, alpha: 1),
    ]

    func typeColor(for type: String) -> UIColor {
        Self.typeColors[type.lowercased()] ?? .systemGray
    }

    func barColor(for value: Int) -> UIColor {
        switch value {
        case ..<50:   return .systemRed
        case 50..<80: return .systemOrange
        case 80..<100: return .systemYellow
        default:      return .systemGreen
        }
    }

    func displayName(for statName: String) -> String {
        switch statName {
        case "hp":              return "HP"
        case "attack":          return "Atk"
        case "defense":         return "Def"
        case "special-attack":  return "Sp. Atk"
        case "special-defense": return "Sp. Def"
        case "speed":           return "Speed"
        default: return statName.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }
}

#if DEBUG
import SwiftUI

#Preview("Pokemon Detail") {
    UINavigationController(
        rootViewController: PokemonDetailViewController(
            repository: PreviewPokemonRepository(),
            pokemon: PreviewPokemonRepository.samplePokemons[0],
            imageLoader: PreviewImageLoader()
        )
    )
}
#endif
