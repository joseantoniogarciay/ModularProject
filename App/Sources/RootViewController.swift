import Core
import Networking
import UIKit

final class RootViewController: UIViewController {
    private let netClient: any NetClient

    init(netClient: any NetClient = AlamofireNetClient(userAgent: RootViewController.defaultUserAgent())) {
        self.netClient = netClient
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "ModularProject"
    }

    private static func defaultUserAgent() -> String {
        let osVersion = UIDevice.current.systemVersion
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        #if DEBUG
        let flavour = "debug"
        #else
        let flavour = "release"
        #endif
        return "iOS/\(osVersion) modular \(appVersion) (\(flavour))"
    }
}
