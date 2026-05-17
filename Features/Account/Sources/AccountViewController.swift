import Core
import SharedUI
import UIKit

@MainActor
public final class AccountViewController: UIViewController {
    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = CoreStrings.accountTitle

        let imageView = UIImageView(image: UIImage(systemName: "person.crop.circle"))
        imageView.tintColor = .secondaryLabel
        imageView.contentMode = .scaleAspectFit
        imageView.pinSize(80)

        let label = UILabel()
        label.text = CoreStrings.accountTitle
        label.font = .preferredFont(forTextStyle: .title2)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [imageView, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        stack.centerInSuperview()
    }
}

#if DEBUG
import SwiftUI

#Preview("Account") {
    UINavigationController(rootViewController: AccountViewController())
}
#endif
