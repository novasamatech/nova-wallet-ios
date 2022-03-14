import UIKit

struct ImageViewModelSettings {
    let targetSize: CGSize
    let cornerRadius: CGFloat?
    let tintColor: UIColor?
}

protocol ImageViewModelProtocol {
    func loadImage(on imageView: UIImageView, settings: ImageViewModelSettings, animated: Bool)
    func cancel(on imageView: UIImageView)
}

extension ImageViewModelProtocol {
    func loadImage(on imageView: UIImageView, targetSize: CGSize, animated: Bool) {
        let settings = ImageViewModelSettings(
            targetSize: targetSize,
            cornerRadius: nil,
            tintColor: nil
        )

        loadImage(on: imageView, settings: settings, animated: animated)
    }

    func loadImage(
        on imageView: UIImageView,
        targetSize: CGSize,
        cornerRadius: CGFloat,
        animated: Bool
    ) {
        let settings = ImageViewModelSettings(
            targetSize: targetSize,
            cornerRadius: cornerRadius,
            tintColor: nil
        )

        loadImage(on: imageView, settings: settings, animated: animated)
    }
}
