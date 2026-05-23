import Core
import SafariServices
import SharedUI
import UIKit

@MainActor
public final class CartViewController: UIViewController {
    private let cartRepository: any CartRepository
    private let productsRepository: any ProductsRepository
    private let onSimulateSessionExpiration: @MainActor () async -> Void

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let itemsCard = UIView()
    private let itemsStack = UIStackView()
    private let totalContainer = UIView()
    private let totalCard = UIView()
    private let totalLabel = UILabel()
    private let retryView = RetryView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let emptyLabel = UILabel()
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
        view.backgroundColor = SharedUIAsset.background.color
        title = CoreStrings.cartScreenTitle
        setupNavigationBar()
        setupCards()
        setupScrollContent()
        setupOverlays()
        updateCardAppearance()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: CartViewController, _: UITraitCollection) in
            self?.updateCardAppearance()
        }
        load()
    }

    private func updateCardAppearance() {
        for card in [itemsCard, totalCard] {
            if traitCollection.userInterfaceStyle == .dark {
                card.layer.shadowOpacity = 0
                card.layer.borderWidth = 0.5
                card.layer.borderColor = UIColor(white: 1.0, alpha: 0.14).cgColor
            } else {
                card.layer.shadowOpacity = 0.09
                card.layer.borderWidth = 0
            }
        }
    }
}

// MARK: - Setup

private extension CartViewController {
    func setupNavigationBar() {
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
    }

    func setupCards() {
        configureCard(itemsCard)
        itemsCard.isHidden = true
        itemsStack.axis = .vertical
        itemsStack.spacing = 0
        itemsStack.alignment = .fill
        itemsStack.translatesAutoresizingMaskIntoConstraints = false
        itemsCard.addSubview(itemsStack)
        NSLayoutConstraint.activate([
            itemsStack.topAnchor.constraint(equalTo: itemsCard.topAnchor),
            itemsStack.leadingAnchor.constraint(equalTo: itemsCard.leadingAnchor),
            itemsStack.trailingAnchor.constraint(equalTo: itemsCard.trailingAnchor),
            itemsStack.bottomAnchor.constraint(equalTo: itemsCard.bottomAnchor),
        ])

        configureCard(totalCard)
        totalCard.translatesAutoresizingMaskIntoConstraints = false
        totalCard.isHidden = true
        totalLabel.font = .preferredFont(forTextStyle: .headline)
        totalLabel.adjustsFontForContentSizeCategory = true
        totalLabel.textColor = SharedUIAsset.text.color
        totalLabel.translatesAutoresizingMaskIntoConstraints = false
        totalCard.addSubview(totalLabel)
        NSLayoutConstraint.activate([
            totalLabel.topAnchor.constraint(equalTo: totalCard.topAnchor, constant: 12),
            totalLabel.bottomAnchor.constraint(equalTo: totalCard.bottomAnchor, constant: -12),
            totalLabel.leadingAnchor.constraint(equalTo: totalCard.leadingAnchor, constant: 16),
            totalLabel.trailingAnchor.constraint(equalTo: totalCard.trailingAnchor, constant: -16),
        ])

        totalContainer.translatesAutoresizingMaskIntoConstraints = false
        totalContainer.addSubview(totalCard)
        NSLayoutConstraint.activate([
            totalCard.topAnchor.constraint(equalTo: totalContainer.topAnchor),
            totalCard.bottomAnchor.constraint(equalTo: totalContainer.bottomAnchor),
            totalCard.trailingAnchor.constraint(equalTo: totalContainer.trailingAnchor),
        ])
    }

    func setupScrollContent() {
        let mainStack = UIStackView(arrangedSubviews: [itemsCard, totalContainer])
        mainStack.axis = .vertical
        mainStack.alignment = .fill
        mainStack.spacing = 16
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.backgroundColor = SharedUIAsset.background.color
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
        contentView.addSubview(mainStack)

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        scrollView.pinEdges(to: view)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            mainStack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24),
        ])
    }

    func setupOverlays() {
        emptyLabel.font = .preferredFont(forTextStyle: .body)
        emptyLabel.adjustsFontForContentSizeCategory = true
        emptyLabel.textColor = SharedUIAsset.secondaryText.color
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.text = CoreStrings.cartEmpty
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            emptyLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        retryView.delegate = self
        retryView.isHidden = true
        view.addSubview(retryView)
        retryView.pinEdges(to: view)

        view.addSubview(spinner)
        spinner.centerInSuperview()
        spinner.hidesWhenStopped = true
    }

    func configureCard(_ card: UIView) {
        card.backgroundColor = SharedUIAsset.cardBackground.color
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowRadius = 10
        card.layer.shadowOffset = CGSize(width: 0, height: 3)
    }
}

// MARK: - Actions & Data

private extension CartViewController {
    func load() {
        guard loadTask == nil else { return }
        spinner.startAnimating()
        scrollView.isHidden = true
        retryView.isHidden = true
        emptyLabel.isHidden = true
        loadTask = Task { await self.performLoad() }
    }

    func performLoad() async {
        defer { loadTask = nil }
        do {
            let fetched = try await cartRepository.get()
            guard !Task.isCancelled else { return }
            handleLoaded(fetched)
        } catch {
            guard !Task.isCancelled else { return }
            handleLoadError(error)
        }
    }

    @objc func addRandomTapped() {
        guard addTask == nil else { return }
        navigationItem.rightBarButtonItems = loadingRightBarItems
        addTask = Task { await self.performAdd() }
    }

    func performAdd() async {
        defer {
            addTask = nil
            navigationItem.rightBarButtonItems = defaultRightBarItems
        }
        let products: [Product]
        do {
            products = try await productsRepository.list()
        } catch {
            guard !Task.isCancelled else { return }
            presentAddError(messageFor(productsError: error))
            return
        }
        guard let productId = products.randomElement()?.id else {
            presentNoProductsDialog()
            return
        }
        do {
            let updated = try await cartRepository.addItem(productId: productId)
            guard !Task.isCancelled else { return }
            handleLoaded(updated)
        } catch {
            guard !Task.isCancelled else { return }
            presentAddError(messageFor(addError: error))
        }
    }

    @objc func simulateExpireTapped() {
        Task { [onSimulateSessionExpiration] in
            await onSimulateSessionExpiration()
        }
    }

    func presentAddError(_ message: String) {
        BannerCenter.shared.show(BannerPayload(
            message: message,
            style: .error,
            iconSystemName: "xmark.circle.fill"
        ))
    }

    func presentNoProductsDialog() {
        let dialog = ConfirmationDialogViewController(
            payload: ConfirmationDialogPayload(
                iconSystemName: "tray",
                title: CoreStrings.cartNoProductsTitle,
                message: CoreStrings.cartNoProductsMessage,
                confirm: ConfirmationDialogAction(title: CoreStrings.cartNoProductsOpenButton) { [weak self] in
                    self?.presentSeedFeedSafari()
                },
                cancel: ConfirmationDialogAction(title: CoreStrings.cartNoProductsCancelButton)
            )
        )
        present(dialog, animated: true)
    }

    func presentSeedFeedSafari() {
        guard let url = URL(string: "https://api.freeapi.app") else { return }
        let safari = SFSafariViewController(url: url)
        present(safari, animated: true)
    }

    func handleLoaded(_ fetched: Cart) {
        spinner.stopAnimating()
        cart = fetched
        if fetched.items.isEmpty {
            scrollView.isHidden = true
            emptyLabel.isHidden = false
            itemsCard.isHidden = true
            totalCard.isHidden = true
        } else {
            emptyLabel.isHidden = true
            scrollView.isHidden = false
            rebuildItems(fetched.items)
            let totalText = Self.priceFormatter.string(from: NSNumber(value: fetched.total))
                ?? String(format: "%.2f", fetched.total)
            totalLabel.text = CoreStrings.cartTotalFormat(totalText)
            itemsCard.isHidden = false
            totalCard.isHidden = false
            updateCardAppearance()
        }
    }

    func rebuildItems(_ items: [CartItem]) {
        itemsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, item) in items.enumerated() {
            if index > 0 { itemsStack.addArrangedSubview(makeSeparator()) }
            itemsStack.addArrangedSubview(makeItemRow(item: item))
        }
    }

    func handleLoadError(_ error: CartFetchError) {
        spinner.stopAnimating()
        scrollView.isHidden = true
        emptyLabel.isHidden = true
        retryView.configure(
            message: messageFor(loadError: error),
            retryTitle: CoreStrings.retryButtonTitle
        )
        retryView.isHidden = false
    }

    func makeItemRow(item: CartItem) -> UIView {
        let nameLabel = UILabel()
        nameLabel.text = item.productName
        nameLabel.font = .preferredFont(forTextStyle: .headline)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.textColor = SharedUIAsset.text.color
        nameLabel.numberOfLines = 0

        let unit = Self.priceFormatter.string(from: NSNumber(value: item.unitPrice))
            ?? String(format: "%.2f", item.unitPrice)
        let detailLabel = UILabel()
        detailLabel.text = CoreStrings.cartItemDetailFormat(unit, item.quantity)
        detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = SharedUIAsset.secondaryText.color

        let subtotal = item.unitPrice * Double(item.quantity)
        let subtotalLabel = UILabel()
        subtotalLabel.text = Self.priceFormatter.string(from: NSNumber(value: subtotal))
            ?? String(format: "%.2f", subtotal)
        subtotalLabel.font = .preferredFont(forTextStyle: .headline)
        subtotalLabel.adjustsFontForContentSizeCategory = true
        subtotalLabel.textColor = SharedUIAsset.text.color
        subtotalLabel.textAlignment = .right
        subtotalLabel.setContentHuggingPriority(.required, for: .horizontal)
        subtotalLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        let row = UIStackView(arrangedSubviews: [textStack, subtotalLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.layoutMargins = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        row.isLayoutMarginsRelativeArrangement = true
        return row
    }

    func makeSeparator() -> UIView {
        let sep = UIView()
        sep.backgroundColor = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return sep
    }

    func messageFor(loadError error: CartFetchError) -> String {
        switch error {
        case .noConnection: return CoreStrings.errorNoConnection
        case .unknown:      return CoreStrings.errorGenericLoading
        }
    }

    func messageFor(productsError error: ProductsListError) -> String {
        switch error {
        case .noConnection: return CoreStrings.errorNoConnection
        case .unknown:      return CoreStrings.cartAddFailed
        }
    }

    func messageFor(addError error: CartAddItemError) -> String {
        switch error {
        case .noConnection: return CoreStrings.errorNoConnection
        case .unknown:      return CoreStrings.cartAddFailed
        }
    }
}

// MARK: - RetryViewDelegate

extension CartViewController: RetryViewDelegate {
    public func retryViewDidTapRetry(_ retryView: RetryView) {
        retryView.isHidden = true
        load()
    }
}
