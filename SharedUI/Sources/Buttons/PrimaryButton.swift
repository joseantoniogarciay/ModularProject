import UIKit

@MainActor
public final class PrimaryButton: UIButton {
    public var isLoading: Bool = false {
        didSet {
            guard oldValue != isLoading else { return }
            configuration?.showsActivityIndicator = isLoading
            isUserInteractionEnabled = !isLoading
            // UIButton.Configuration can clear isAccessibilityElement when showing a spinner.
            // Explicitly maintain it so VoiceOver announces "Continue, dimmed" during loading.
            isAccessibilityElement = true
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func setup() {
        var config = UIButton.Configuration.filled()
        config.background.backgroundColor = SharedUIAsset.text.color
        config.background.cornerRadius = 14
        config.baseForegroundColor = SharedUIAsset.background.color
        config.imagePlacement = .trailing
        config.imagePadding = 8
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .preferredFont(forTextStyle: .headline)
            return outgoing
        }
        config.activityIndicatorColorTransformer = UIConfigurationColorTransformer { _ in
            SharedUIAsset.background.color
        }
        configuration = config
        heightAnchor.constraint(equalToConstant: 52).isActive = true

        configurationUpdateHandler = { button in
            button.alpha = button.isHighlighted ? 0.7 : 1
        }
    }
}

#if DEBUG
import SwiftUI

#Preview("Primary Button") {
    let viewController = UIViewController()
    viewController.view.backgroundColor = SharedUIAsset.background.color

    let button = PrimaryButton()
    button.setTitle("Continue", for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.isLoading = true
    viewController.view.addSubview(button)

    NSLayoutConstraint.activate([
        button.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
        button.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor, constant: 24),
        button.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor, constant: -24),
    ])

    return viewController
}
#endif
