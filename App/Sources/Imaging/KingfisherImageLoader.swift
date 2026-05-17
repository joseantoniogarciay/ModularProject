import Kingfisher
import SharedUI
import UIKit

@MainActor
final class KingfisherImageLoader: ImageLoader {
    func setImage(_ url: URL?, placeholder: UIImage?, on imageView: UIImageView) {
        imageView.kf.setImage(with: url, placeholder: placeholder)
    }

    func cancel(on imageView: UIImageView) {
        imageView.kf.cancelDownloadTask()
    }
}
