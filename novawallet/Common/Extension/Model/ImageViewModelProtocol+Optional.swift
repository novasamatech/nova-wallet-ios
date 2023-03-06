import UIKit

extension Optional where Wrapped == ImageViewModelProtocol {
    func loadImageOrClear(imageView: UIImageView, targetSize: CGSize, animated: Bool) {
        guard let self = self else {
            imageView.image = nil
            return
        }
        self.loadImage(on: imageView, targetSize: targetSize, animated: animated)
    }

    func loadImageOrClear(
        imageView: UIImageView,
        targetSize: CGSize,
        cornerRadius: CGFloat,
        animated: Bool
    ) {
        guard let self = self else {
            imageView.image = nil
            return
        }

        self.loadImage(
            on: imageView,
            targetSize: targetSize,
            cornerRadius: cornerRadius,
            animated: animated
        )
    }
}
