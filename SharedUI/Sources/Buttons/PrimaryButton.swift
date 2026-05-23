import UIKit

@MainActor
public final class PrimaryButton: UIButton {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    public override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }

    private func setup() {
        backgroundColor = SharedUIAsset.text.color
        setTitleColor(SharedUIAsset.background.color, for: .normal)
        titleLabel?.font = .preferredFont(forTextStyle: .headline)
        titleLabel?.adjustsFontForContentSizeCategory = true
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        heightAnchor.constraint(equalToConstant: 52).isActive = true
    }
}
