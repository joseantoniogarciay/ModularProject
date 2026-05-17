import Core
import SharedUI
import UIKit

@MainActor
public final class PokemonListViewController: UIViewController {
    private let repository: any PokemonRepository
    private let onSelect: @MainActor (Pokemon) -> Void
    private let pageSize: Int

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let retryView = RetryView()
    private var pokemons: [Pokemon] = []
    private var offset: Int = 0
    private var hasMore: Bool = true
    private var loadTask: Task<Void, Never>?

    private enum Section: Int, CaseIterable {
        case items
        case loader
    }

    public init(
        repository: any PokemonRepository,
        pageSize: Int = 30,
        onSelect: @escaping @MainActor (Pokemon) -> Void
    ) {
        self.repository = repository
        self.pageSize = pageSize
        self.onSelect = onSelect
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
        setupUI()
        loadNext()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = CoreStrings.pokemonTitle

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(PokemonCell.self, forCellReuseIdentifier: PokemonCell.reuseID)
        tableView.register(LoaderCell.self, forCellReuseIdentifier: LoaderCell.reuseID)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72

        view.addSubview(tableView)
        tableView.pinEdges(to: view)

        retryView.delegate = self
        retryView.isHidden = true
        view.addSubview(retryView)
        retryView.pinEdges(to: view)
    }

    private func loadNext() {
        guard hasMore, loadTask == nil else { return }
        let currentOffset = offset
        let currentPageSize = pageSize
        loadTask = Task { [repository] in
            defer { self.loadTask = nil }
            do {
                let batch = try await repository.list(offset: currentOffset, limit: currentPageSize)
                guard !Task.isCancelled else { return }
                self.appendBatch(batch)
            } catch is CancellationError {
                return
            } catch {
                self.handleLoadError(error)
            }
        }
    }

    private func appendBatch(_ batch: [Pokemon]) {
        let previousCount = pokemons.count
        pokemons.append(contentsOf: batch)
        offset += batch.count
        let hadMore = hasMore
        if batch.count < pageSize {
            hasMore = false
        }

        tableView.performBatchUpdates {
            if !batch.isEmpty {
                let newIndexPaths = (previousCount..<pokemons.count).map {
                    IndexPath(row: $0, section: Section.items.rawValue)
                }
                tableView.insertRows(at: newIndexPaths, with: .none)
            }
            if hadMore != hasMore {
                tableView.reloadSections([Section.loader.rawValue], with: .none)
            }
        }
    }

    private func handleLoadError(_ error: any Error) {
        if pokemons.isEmpty {
            retryView.configure(
                message: messageFor(error),
                retryTitle: CoreStrings.retryButtonTitle
            )
            tableView.isHidden = true
            retryView.isHidden = false
        } else {
            presentError(error)
        }
    }

    private func messageFor(_ error: any Error) -> String {
        if let netError = error as? NetError, case .noConnection = netError {
            return CoreStrings.errorNoConnection
        }
        return CoreStrings.errorGenericLoading
    }

    private func presentError(_ error: any Error) {
        let alert = UIAlertController(
            title: "Error",
            message: String(describing: error),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension PokemonListViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .items: return pokemons.count
        case .loader: return hasMore ? 1 : 0
        case .none: return 0
        }
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .items:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: PokemonCell.reuseID, for: indexPath) as? PokemonCell else {
                return UITableViewCell()
            }
            cell.configure(with: pokemons[indexPath.row])
            return cell
        case .loader:
            return tableView.dequeueReusableCell(withIdentifier: LoaderCell.reuseID, for: indexPath)
        case .none:
            return UITableViewCell()
        }
    }
}

extension PokemonListViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard Section(rawValue: indexPath.section) == .items else { return }
        onSelect(pokemons[indexPath.row])
    }

    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if Section(rawValue: indexPath.section) == .loader {
            loadNext()
        }
    }
}

extension PokemonListViewController: RetryViewDelegate {
    public func retryViewDidTapRetry(_ retryView: RetryView) {
        retryView.isHidden = true
        tableView.isHidden = false
        loadNext()
    }
}

#if DEBUG
import SwiftUI

#Preview("Pokemon List") {
    UINavigationController(
        rootViewController: PokemonListViewController(
            repository: PreviewPokemonRepository(),
            onSelect: { _ in }
        )
    )
}
#endif
