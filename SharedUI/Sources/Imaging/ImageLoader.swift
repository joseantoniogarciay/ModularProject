import UIKit

@MainActor
public protocol ImageLoader: Sendable {
    func setImage(_ url: URL?, placeholder: UIImage?, on imageView: UIImageView)
    func cancel(on imageView: UIImageView)
}
