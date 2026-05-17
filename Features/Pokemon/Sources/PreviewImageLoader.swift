#if DEBUG
import SharedUI
import UIKit

@MainActor
struct PreviewImageLoader: ImageLoader {
    func setImage(_ url: URL?, placeholder: UIImage?, on imageView: UIImageView) {
        imageView.image = placeholder
    }

    func cancel(on imageView: UIImageView) {}
}
#endif
