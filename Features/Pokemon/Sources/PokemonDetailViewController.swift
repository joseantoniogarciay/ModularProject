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
    private let typesLabel = UILabel()
    private let metricsLabel = UILabel()
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
        view.backgroundColor = .systemBackground
        title = pokemon.name.capitalized
        setupUI()
        showInitial()
        loadDetail()
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.pinEdges(to: view)

        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        scrollView.addSubview(stackView)
        stackView.pinEdges(to: scrollView)
        stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true

        spriteImageView.contentMode = .scaleAspectFit
        spriteImageView.tintColor = .secondaryLabel
        spriteImageView.translatesAutoresizingMaskIntoConstraints = false
        spriteImageView.heightAnchor.constraint(equalToConstant: 220).isActive = true
        stackView.addArrangedSubview(spriteImageView)

        typesLabel.numberOfLines = 0
        typesLabel.font = .preferredFont(forTextStyle: .headline)
        typesLabel.adjustsFontForContentSizeCategory = true
        stackView.addArrangedSubview(typesLabel)

        metricsLabel.numberOfLines = 0
        metricsLabel.font = .preferredFont(forTextStyle: .body)
        metricsLabel.adjustsFontForContentSizeCategory = true
        stackView.addArrangedSubview(metricsLabel)

        statsHeaderLabel.text = "Stats"
        statsHeaderLabel.font = .preferredFont(forTextStyle: .headline)
        statsHeaderLabel.adjustsFontForContentSizeCategory = true
        stackView.addArrangedSubview(statsHeaderLabel)

        statsStackView.axis = .vertical
        statsStackView.spacing = 8
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
        typesLabel.isHidden = true
        metricsLabel.isHidden = true
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

        typesLabel.text = "Types: \(detail.types.joined(separator: ", "))"
        typesLabel.isHidden = false

        let heightInMetres = Double(detail.heightDecimetres) / 10.0
        let weightInKilos = Double(detail.weightHectograms) / 10.0
        metricsLabel.text = String(
            format: "Height: %.1f m    Weight: %.1f kg",
            heightInMetres,
            weightInKilos
        )
        metricsLabel.isHidden = false

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

    private func makeStatRow(_ stat: PokemonStat) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.distribution = .equalSpacing

        let nameLabel = UILabel()
        nameLabel.text = stat.name.replacingOccurrences(of: "-", with: " ").capitalized
        nameLabel.font = .preferredFont(forTextStyle: .body)
        nameLabel.adjustsFontForContentSizeCategory = true

        let valueLabel = UILabel()
        valueLabel.text = "\(stat.baseValue)"
        valueLabel.font = .preferredFont(forTextStyle: .body)
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.textColor = .secondaryLabel

        row.addArrangedSubview(nameLabel)
        row.addArrangedSubview(valueLabel)
        return row
    }
}

extension PokemonDetailViewController: RetryViewDelegate {
    public func retryViewDidTapRetry(_ retryView: RetryView) {
        loadDetail()
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
