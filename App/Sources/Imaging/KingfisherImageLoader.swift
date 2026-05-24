import Kingfisher
import SharedUI
import UIKit

@MainActor
final class KingfisherImageLoader: ImageLoader {
    func setImage(_ url: URL?, placeholder: UIImage?, on imageView: UIImageView) {
        imageView.kf.indicatorType = .activity
        imageView.kf.setImage(
            with: url,
            placeholder: nil,
            options: [.transition(.fade(0.25))]
        ) { [weak imageView] result in
            if case .failure = result {
                imageView?.image = placeholder
            }
        }
    }

    func cancel(on imageView: UIImageView) {
        imageView.kf.cancelDownloadTask()
    }
}
