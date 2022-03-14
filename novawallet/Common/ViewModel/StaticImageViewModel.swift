import Foundation
import UIKit

final class StaticImageViewModel: ImageViewModelProtocol {
    let image: UIImage

    init(image: UIImage) {
        self.image = image
    }

    func loadImage(on imageView: UIImageView, settings: ImageViewModelSettings, animated _: Bool) {
        if let tintColor = settings.tintColor {
            imageView.image = image.tinted(with: tintColor)
        } else {
            imageView.image = image
        }
    }

    func cancel(on _: UIImageView) {}
}
