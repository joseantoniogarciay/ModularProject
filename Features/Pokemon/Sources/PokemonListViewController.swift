import Core
import SharedUI
import UIKit
import UserNotifications

@MainActor
public final class PokemonListViewController: UIViewController {
    private let repository: any PokemonRepository
    private let imageLoader: any ImageLoader
    private let themeStore: any ThemeStore
    private let onSelect: @MainActor (Pokemon) -> Void
    private let pageSize: Int

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let retryView = RetryView()
    private var themeBarButton: UIBarButtonItem?
    private var pokemons: [Pokemon] = []
    private var offset: Int = 0
    private var hasMore: Bool = true
    private var pageErrorMessage: String?
    private var loadTask: Task<Void, Never>?

    private enum Section: Int, CaseIterable {
        case items
        case loader
    }

    public init(
        repository: any PokemonRepository,
        imageLoader: any ImageLoader,
        themeStore: any ThemeStore,
        pageSize: Int = 30,
        onSelect: @escaping @MainActor (Pokemon) -> Void
    ) {
        self.repository = repository
        self.imageLoader = imageLoader
        self.themeStore = themeStore
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
        view.backgroundColor = SharedUIAsset.background.color

        let themeButton = UIBarButtonItem(
            symbolName: themeStore.current.systemImageName,
            accessibilityLabel: CoreStrings.accessibilityChangeAppearance,
            target: self,
            action: #selector(themeButtonTapped)
        )
        let notificationButton = UIBarButtonItem(
            symbolName: "bell.badge",
            accessibilityLabel: CoreStrings.accessibilityNotifyMe,
            target: self,
            action: #selector(notificationButtonTapped)
        )
        navigationItem.rightBarButtonItems = [themeButton, notificationButton]
        themeBarButton = themeButton

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(PokemonCell.self, forCellReuseIdentifier: PokemonCell.reuseID)
        tableView.register(LoaderCell.self, forCellReuseIdentifier: LoaderCell.reuseID)
        tableView.register(RetryCell.self, forCellReuseIdentifier: RetryCell.reuseID)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 108
        tableView.separatorStyle = .none
        tableView.backgroundColor = SharedUIAsset.background.color

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
        loadTask = Task {
            await self.performLoad(offset: currentOffset, pageSize: currentPageSize)
        }
    }

    private func performLoad(offset: Int, pageSize: Int) async {
        defer { loadTask = nil }
        do {
            let batch = try await repository.list(offset: offset, limit: pageSize)
            guard !Task.isCancelled else { return }
            pageErrorMessage = nil
            appendBatch(batch)
        } catch {
            guard !Task.isCancelled else { return }
            handleLoadError(error)
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

    private func handleLoadError(_ error: PokemonListError) {
        if pokemons.isEmpty {
            retryView.configure(
                message: messageFor(error),
                retryTitle: CoreStrings.retryButtonTitle
            )
            tableView.isHidden = true
            retryView.isHidden = false
        } else {
            pageErrorMessage = messageFor(error)
            tableView.reloadSections([Section.loader.rawValue], with: .none)
        }
    }

    private func retryPage() {
        pageErrorMessage = nil
        tableView.reloadSections([Section.loader.rawValue], with: .none)
        loadNext()
    }

    private func messageFor(_ error: PokemonListError) -> String {
        switch error {
        case .noConnection: return CoreStrings.errorNoConnection
        case .unknown:      return CoreStrings.errorGenericLoading
        }
    }
}

extension PokemonListViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .items: return pokemons.count
        case .loader: return (hasMore || pageErrorMessage != nil) ? 1 : 0
        case .none: return 0
        }
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .items:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: PokemonCell.reuseID, for: indexPath) as? PokemonCell else {
                return UITableViewCell()
            }
            cell.configure(with: pokemons[indexPath.row], imageLoader: imageLoader)
            return cell
        case .loader:
            if let message = pageErrorMessage {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: RetryCell.reuseID, for: indexPath) as? RetryCell else {
                    return UITableViewCell()
                }
                cell.configure(message: message, retryTitle: CoreStrings.retryButtonTitle, onRetry: retryPage)
                return cell
            }
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
        if Section(rawValue: indexPath.section) == .loader, cell is LoaderCell {
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

extension PokemonListViewController {
    @objc private func themeButtonTapped() {
        let next = themeStore.current.next
        themeStore.set(next)
        themeBarButton?.image = UIImage(systemName: next.systemImageName)
        view.window?.overrideUserInterfaceStyle = next.uiStyle
    }

    @objc private func notificationButtonTapped() {
        Task { await scheduleMewtwoNotification() }
    }

    private func scheduleMewtwoNotification() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return }
        } catch {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "A wild Pokémon appears"
        content.body = "Tap to meet #151."
        content.sound = .default
        content.userInfo = ["pokemon_id": 151]

        let request = UNNotificationRequest(
            identifier: "pokemon.detail.151",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}

private extension ThemePreference {
    var systemImageName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var uiStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}

#if DEBUG
import SwiftUI

#Preview("Pokemon List") {
    UINavigationController(
        rootViewController: PokemonListViewController(
            repository: PreviewPokemonRepository(),
            imageLoader: PreviewImageLoader(),
            themeStore: UserDefaultsThemeStore(),
            onSelect: { _ in }
        )
    )
}
#endif
