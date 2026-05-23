import UIKit

public final class LoaderCell: UITableViewCell {
    public static let reuseID = "LoaderCell"

    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        activityIndicator.startAnimating()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        activityIndicator.startAnimating()
    }

    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear
        activityIndicator.hidesWhenStopped = false
        contentView.addSubview(activityIndicator)
        activityIndicator.centerInSuperview()
        contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
    }
}

#if DEBUG
import SwiftUI

#Preview("LoaderCell") {
    CellPreview(LoaderCell(style: .default, reuseIdentifier: nil), height: 56)
}
#endif
