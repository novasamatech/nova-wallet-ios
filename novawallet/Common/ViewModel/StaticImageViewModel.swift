import Foundation
import UIKit

final class StaticImageViewModel: ImageViewModelProtocol {
    let image: UIImage

    init(image: UIImage) {
        self.image = image
    }

    func loadImage(on imageView: UIImageView, targetSize _: CGSize, cornerRadius _: CGFloat, animated _: Bool) {
        imageView.image = image
    }

    func cancel(on _: UIImageView) {}
}
