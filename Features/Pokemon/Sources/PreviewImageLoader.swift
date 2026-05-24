#if DEBUG
import SharedUI
import UIKit

@MainActor
public struct PreviewImageLoader: ImageLoader {
    public init() {}
    public func setImage(_ url: URL?, placeholder: UIImage?, on imageView: UIImageView) {
        imageView.image = placeholder
    }

    public func cancel(on imageView: UIImageView) {}
}
#endif
