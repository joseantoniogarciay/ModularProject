import Core
import SharedUI
import UIKit

@MainActor
public final class CartViewController: UIViewController {
    private let cartRepository: any CartRepository
    private let productsRepository: any ProductsRepository
    private let onSimulateSessionExpiration: @MainActor () async -> Void

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let retryView = RetryView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let emptyLabel = UILabel()
    private let footerView = CartTotalFooterView()
    private var cart = Cart(items: [], total: 0)
    private var loadTask: Task<Void, Never>?
    private var addTask: Task<Void, Never>?
    private var defaultRightBarItems: [UIBarButtonItem] = []
    private var loadingRightBarItems: [UIBarButtonItem] = []

    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()

    public init(
        cartRepository: any CartRepository,
        productsRepository: any ProductsRepository,
        onSimulateSessionExpiration: @escaping @MainActor () async -> Void
    ) {
        self.cartRepository = cartRepository
        self.productsRepository = productsRepository
        self.onSimulateSessionExpiration = onSimulateSessionExpiration
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    deinit {
        loadTask?.cancel()
        addTask?.cancel()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        load()
    }

    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        title = CoreStrings.cartScreenTitle

        let addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addRandomTapped)
        )

        let expireButton = UIBarButtonItem(
            title: CoreStrings.cartSimulateExpireButton,
            style: .plain,
            target: self,
            action: #selector(simulateExpireTapped)
        )
        expireButton.tintColor = .systemRed

        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.startAnimating()
        let activityItem = UIBarButtonItem(customView: activityIndicator)

        defaultRightBarItems = [addButton, expireButton]
        loadingRightBarItems = [activityItem, expireButton]
        navigationItem.rightBarButtonItems = defaultRightBarItems

        tableView.register(CartItemCell.self, forCellReuseIdentifier: CartItemCell.reuseID)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        tableView.isHidden = true

        view.addSubview(tableView)
        tableView.pinEdges(to: view)

        retryView.delegate = self
        retryView.isHidden = true
        view.addSubview(retryView)
        retryView.pinEdges(to: view)

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.font = .preferredFont(forTextStyle: .body)
        emptyLabel.adjustsFontForContentSizeCategory = true
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.text = CoreStrings.cartEmpty
        emptyLabel.isHidden = true
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            emptyLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        view.addSubview(spinner)
        spinner.centerInSuperview()
        spinner.hidesWhenStopped = true
    }

    private func load() {
        guard loadTask == nil else { return }
        spinner.startAnimating()
        tableView.isHidden = true
        retryView.isHidden = true
        emptyLabel.isHidden = true

        loadTask = Task { [cartRepository] in
            defer { self.loadTask = nil }
            do {
                let fetched = try await cartRepository.get()
                guard !Task.isCancelled else { return }
                self.handleLoaded(fetched)
            } catch is CancellationError {
                return
            } catch {
                self.handleLoadError(error)
            }
        }
    }

    @objc private func addRandomTapped() {
        guard addTask == nil else { return }
        navigationItem.rightBarButtonItems = loadingRightBarItems

        addTask = Task { [cartRepository, productsRepository] in
            defer {
                self.addTask = nil
                self.navigationItem.rightBarButtonItems = self.defaultRightBarItems
            }
            do {
                let products = try await productsRepository.list()
                guard let productId = products.randomElement()?.id else {
                    self.presentAddError(CoreStrings.cartAddFailed)
                    return
                }
                let updated = try await cartRepository.addItem(productId: productId)
                guard !Task.isCancelled else { return }
                self.handleLoaded(updated)
            } catch is CancellationError {
                return
            } catch {
                self.presentAddError(CoreStrings.cartAddFailed)
            }
        }
    }

    @objc private func simulateExpireTapped() {
        Task { [onSimulateSessionExpiration] in
            await onSimulateSessionExpiration()
        }
    }

    private func presentAddError(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func handleLoaded(_ fetched: Cart) {
        spinner.stopAnimating()
        cart = fetched
        if fetched.items.isEmpty {
            tableView.isHidden = true
            emptyLabel.isHidden = false
        } else {
            emptyLabel.isHidden = true
            tableView.isHidden = false
            let totalText = Self.priceFormatter.string(from: NSNumber(value: fetched.total))
                ?? String(format: "%.2f", fetched.total)
            footerView.configure(totalText: CoreStrings.cartTotalFormat(totalText))
            tableView.tableFooterView = footerView
            footerView.layout(for: tableView.bounds.width)
            tableView.reloadData()
        }
    }

    private func handleLoadError(_ error: any Error) {
        spinner.stopAnimating()
        retryView.configure(
            message: messageFor(error),
            retryTitle: CoreStrings.retryButtonTitle
        )
        tableView.isHidden = true
        emptyLabel.isHidden = true
        retryView.isHidden = false
    }

    private func messageFor(_ error: any Error) -> String {
        if let netError = error as? NetError, case .noConnection = netError {
            return CoreStrings.errorNoConnection
        }
        return CoreStrings.errorGenericLoading
    }
}

extension CartViewController: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        cart.items.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: CartItemCell.reuseID, for: indexPath) as? CartItemCell else {
            return UITableViewCell()
        }
        cell.configure(with: cart.items[indexPath.row])
        return cell
    }
}

extension CartViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension CartViewController: RetryViewDelegate {
    public func retryViewDidTapRetry(_ retryView: RetryView) {
        retryView.isHidden = true
        load()
    }
}

private final class CartTotalFooterView: UIView {
    private let totalLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        totalLabel.translatesAutoresizingMaskIntoConstraints = false
        totalLabel.font = .preferredFont(forTextStyle: .headline)
        totalLabel.adjustsFontForContentSizeCategory = true
        totalLabel.textAlignment = .right
        addSubview(totalLabel)

        NSLayoutConstraint.activate([
            totalLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            totalLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            totalLabel.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            totalLabel.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    func configure(totalText: String) {
        totalLabel.text = totalText
    }

    func layout(for width: CGFloat) {
        frame = CGRect(x: 0, y: 0, width: width, height: 0)
        setNeedsLayout()
        layoutIfNeeded()
        let height = systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        frame = CGRect(x: 0, y: 0, width: width, height: height)
    }
}
