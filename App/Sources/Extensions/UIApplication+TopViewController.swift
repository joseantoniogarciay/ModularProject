import UIKit

extension UIApplication {
    static func getTopViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        guard let root = keyWindow?.rootViewController else { return nil }
        return topMost(of: root)
    }

    private static func topMost(of controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController {
            return topMost(of: presented)
        }
        if let nav = controller as? UINavigationController, let top = nav.topViewController {
            return topMost(of: top)
        }
        if let tab = controller as? UITabBarController, let selected = tab.selectedViewController {
            return topMost(of: selected)
        }
        return controller
    }
}
