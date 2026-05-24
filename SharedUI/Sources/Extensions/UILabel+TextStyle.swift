import UIKit

public extension UILabel {
    /// Apply a Dynamic Type text style. Sets `font` to the preferred font for the style and
    /// enables `adjustsFontForContentSizeCategory` so the label reacts to live size changes.
    func applyTextStyle(_ style: UIFont.TextStyle) {
        font = .preferredFont(forTextStyle: style)
        adjustsFontForContentSizeCategory = true
    }

    /// Apply a custom-sized font that still scales with Dynamic Type relative to `style`.
    /// Use only when the design system requires a size that no `UIFont.TextStyle` provides.
    func applyScaledFont(size: CGFloat, weight: UIFont.Weight, relativeTo style: UIFont.TextStyle) {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        font = UIFontMetrics(forTextStyle: style).scaledFont(for: base)
        adjustsFontForContentSizeCategory = true
    }
}
