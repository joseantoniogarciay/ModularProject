#if DEV
import PulseUI
import SwiftUI
import UIKit

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake,
              let topViewController = UIApplication.getTopViewController()
        else { return }
        if topViewController.isHosting {
            topViewController.dismiss(animated: true)
        } else {
            let hostingController = UIHostingController(rootView: ConsoleView())
            let nav = UINavigationController(rootViewController: hostingController)
            topViewController.present(nav, animated: true)
        }
    }
}

private protocol AnyUIHostingViewController: AnyObject {}
extension UIHostingController: AnyUIHostingViewController {}
extension UIViewController {
    var isHosting: Bool { self is AnyUIHostingViewController }
}
#endif
