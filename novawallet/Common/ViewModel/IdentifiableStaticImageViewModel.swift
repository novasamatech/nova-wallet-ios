import UIKit

final class IdentifiableStaticImageViewModel: IdentifiableImageViewModelProtocol {
    let staticViewModel: StaticImageViewModel
    let identifier: String

    init(image: UIImage, identifier: String) {
        staticViewModel = StaticImageViewModel(image: image)
        self.identifier = identifier
    }

    func loadImage(on imageView: UIImageView, settings: ImageViewModelSettings, animated: Bool) {
        staticViewModel.loadImage(on: imageView, settings: settings, animated: animated)
    }

    func cancel(on imageView: UIImageView) {
        staticViewModel.cancel(on: imageView)
    }
}
