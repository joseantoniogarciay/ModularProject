import UIKit

@MainActor
public final class TextLinkButton: UIButton {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel?.adjustsFontForContentSizeCategory = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    public override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.5 : 1 }
    }

    public override func setTitle(_ title: String?, for state: UIControl.State) {
        guard let title else {
            super.setAttributedTitle(nil, for: state)
            return
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .foregroundColor: SharedUIAsset.text.color,
            .font: UIFont.preferredFont(forTextStyle: .subheadline),
        ]
        super.setAttributedTitle(NSAttributedString(string: title, attributes: attrs), for: state)
    }
}
