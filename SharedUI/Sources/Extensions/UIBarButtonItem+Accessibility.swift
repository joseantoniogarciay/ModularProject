import UIKit

public extension UIBarButtonItem {
    /// SF Symbol bar button that REQUIRES an `accessibilityLabel`. Use this instead of the
    /// system `init(image:style:target:action:)` for icon-only bar buttons — VoiceOver users
    /// hear the symbol's system name otherwise.
    convenience init(
        symbolName: String,
        accessibilityLabel: String,
        target: Any?,
        action: Selector
    ) {
        self.init(
            image: UIImage(systemName: symbolName),
            style: .plain,
            target: target,
            action: action
        )
        self.accessibilityLabel = accessibilityLabel
    }
}
