import Foundation
import UIKit

final class StaticImageViewModel: ImageViewModelProtocol {
    let image: UIImage

    init(image: UIImage) {
        self.image = image
    }

    func loadImage(on imageView: UIImageView, settings: ImageViewModelSettings, animated _: Bool) {
        let newImage: UIImage?
        if let tintColor = settings.tintColor {
            newImage = image.tinted(with: tintColor)
        } else {
            newImage = image
        }

        if let renderingMode = settings.renderingMode {
            imageView.image = newImage?.withRenderingMode(renderingMode)
        } else {
            imageView.image = newImage
        }
    }

    func cancel(on _: UIImageView) {}
}
