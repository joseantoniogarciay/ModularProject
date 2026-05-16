import Core
import Networking
import UIKit

final class RootViewController: UIViewController {
    private let api: any APIClient

    init(api: any APIClient = URLSessionAPIClient(baseURL: URL(string: "https://example.com")!)) {
        self.api = api
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
}
