import Operation_iOS
typealias IdentifiableImageViewModelProtocol = ImageViewModelProtocol & Identifiable

final class IdentifiableDrawableIconViewModel: IdentifiableImageViewModelProtocol {
    let drawableIcon: DrawableIconViewModel
    let identifier: String

    init(_ drawableIcon: DrawableIconViewModel, identifier: String) {
        self.drawableIcon = drawableIcon
        self.identifier = identifier
    }

    func loadImage(on imageView: UIImageView, settings: ImageViewModelSettings, animated: Bool) {
        drawableIcon.loadImage(on: imageView, settings: settings, animated: animated)
    }

    func cancel(on imageView: UIImageView) {
        drawableIcon.cancel(on: imageView)
    }
}
