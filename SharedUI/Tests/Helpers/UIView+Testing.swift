import UIKit

// MARK: - View hierarchy helpers for unit tests

extension UIView {
    /// Returns all descendant views of the given type, depth-first.
    @MainActor
    func findSubviews<T: UIView>(ofType type: T.Type) -> [T] {
        var result = subviews.compactMap { $0 as? T }
        result += subviews.flatMap { $0.findSubviews(ofType: type) }
        return result
    }

    /// Returns true if this view is nested inside a UIButton somewhere in its superview chain.
    /// Useful to exclude button title labels from checks that only apply to standalone labels.
    @MainActor
    var isInsideButton: Bool {
        var ancestor: UIView? = superview
        while let view = ancestor {
            if view is UIButton { return true }
            ancestor = view.superview
        }
        return false
    }
}
