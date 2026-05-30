import UIKit

@MainActor
public final class BannerCenter {
    public static let shared = BannerCenter()

    private var bannerWindow: BannerWindow?
    private var currentBanner: BannerView?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    public func show(_ payload: BannerPayload) {
        ensureWindow()
        syncAppearance()
        dismissTask?.cancel()
        dismissTask = nil

        if let existing = currentBanner {
            existing.removeFromSuperview()
            currentBanner = nil
        }

        guard let bannerWindow,
              let rootView = bannerWindow.rootViewController?.view else {
            return
        }

        let banner = BannerView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.configure(with: payload)
        banner.onDismiss = { [weak self] in
            self?.dismiss()
        }
        rootView.addSubview(banner)
        currentBanner = banner

        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: 8),
            banner.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 12),
            banner.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -12),
        ])

        rootView.layoutIfNeeded()
        banner.transform = CGAffineTransform(translationX: 0, y: -banner.frame.height - 60)
        UIView.animate(
            withDuration: 0.45,
            delay: 0,
            usingSpringWithDamping: 0.75,
            initialSpringVelocity: 0.6,
            options: [.allowUserInteraction]
        ) {
            banner.transform = .identity
        }

        let duration = payload.duration
        dismissTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(duration))
            } catch {
                return
            }
            self?.dismiss()
        }
    }

    public func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        guard let banner = currentBanner else {
            hideWindowIfIdle()
            return
        }
        currentBanner = nil

        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: [.curveEaseIn, .allowUserInteraction],
            animations: {
                banner.transform = CGAffineTransform(translationX: 0, y: -banner.frame.height - 60)
                banner.alpha = 0
            },
            completion: { [weak self] _ in
                banner.removeFromSuperview()
                self?.hideWindowIfIdle()
            }
        )
    }

    private func ensureWindow() {
        if let bannerWindow {
            bannerWindow.isHidden = false
            return
        }
        guard let windowScene = activeWindowScene() else { return }
        let window = BannerWindow(windowScene: windowScene)
        window.windowLevel = UIWindow.Level.alert + 1
        window.backgroundColor = .clear
        let root = UIViewController()
        root.view.backgroundColor = .clear
        window.rootViewController = root
        window.isHidden = false
        bannerWindow = window
    }

    private func hideWindowIfIdle() {
        guard currentBanner == nil else { return }
        bannerWindow?.isHidden = true
    }

    /// Mirrors the app's forced appearance onto the banner's own window.
    /// The banner lives in a separate `UIWindow`, so a theme override applied to the
    /// main app window (see `themeButtonTapped`) would otherwise not reach it and the
    /// banner would follow the system appearance instead.
    private func syncAppearance() {
        guard let bannerWindow, let windowScene = activeWindowScene() else { return }
        let appWindow = windowScene.windows.first { !($0 is BannerWindow) }
        bannerWindow.overrideUserInterfaceStyle = appWindow?.overrideUserInterfaceStyle ?? .unspecified
    }

    private func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}

private final class BannerWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        if hit === rootViewController?.view || hit === self {
            return nil
        }
        return hit
    }
}
