import UIKit

public final class BusyOverlay: UIView {
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    public func show(in parent: UIView) {
        guard superview !== parent else { return }
        parent.addSubview(self)
        pinEdges(to: parent)
        activityIndicator.startAnimating()
    }

    public func hide() {
        activityIndicator.stopAnimating()
        removeFromSuperview()
    }

    private func setupViews() {
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.7)
        isUserInteractionEnabled = true

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(activityIndicator)
        activityIndicator.centerInSuperview()
    }
}

#if DEBUG
import SwiftUI

#Preview("BusyOverlay") {
    let container = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 600))
    container.backgroundColor = .systemBackground
    let label = UILabel()
    label.text = "Underlying content"
    label.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(label)
    label.centerInSuperview()
    let overlay = BusyOverlay()
    overlay.show(in: container)
    return container
}
#endif
