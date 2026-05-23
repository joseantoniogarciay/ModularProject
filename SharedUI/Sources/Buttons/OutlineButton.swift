import UIKit

@MainActor
public final class OutlineButton: UIButton {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    public override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.5 : 1 }
    }

    private func setup() {
        backgroundColor = .clear
        setTitleColor(SharedUIAsset.text.color, for: .normal)
        titleLabel?.font = .preferredFont(forTextStyle: .headline)
        titleLabel?.adjustsFontForContentSizeCategory = true
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = SharedUIAsset.text.color.cgColor
        heightAnchor.constraint(equalToConstant: 52).isActive = true

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: OutlineButton, _) in
            self.layer.borderColor = SharedUIAsset.text.color.cgColor
        }
    }
}
