import UIKit

protocol ImageViewModelProtocol {
    func loadImage(on imageView: UIImageView, targetSize: CGSize, cornerRadius: CGFloat?, animated: Bool)
    func cancel(on imageView: UIImageView)
}

extension ImageViewModelProtocol {
    func loadImage(on imageView: UIImageView, targetSize: CGSize, animated: Bool) {
        loadImage(on: imageView, targetSize: targetSize, cornerRadius: nil, animated: animated)
    }
}
