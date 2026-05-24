import UIKit

public extension UIButton {
    /// Apply a Dynamic Type text style to the button's `titleLabel`. Sets the preferred font
    /// for the style and enables `adjustsFontForContentSizeCategory` on the title label.
    ///
    /// Does NOT apply to buttons configured via `UIButton.Configuration` (use a
    /// `titleTextAttributesTransformer` inside the configuration block) nor to attributed-title
    /// flows (set the font as part of the `NSAttributedString` attributes).
    func applyTextStyle(_ style: UIFont.TextStyle) {
        titleLabel?.font = .preferredFont(forTextStyle: style)
        titleLabel?.adjustsFontForContentSizeCategory = true
    }
}
