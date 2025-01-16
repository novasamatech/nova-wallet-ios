import UIKit

struct ImageViewModelSettings {
    let targetSize: CGSize
    let cornerRadius: CGFloat?
    let tintColor: UIColor?
    let opacity: CGFloat?
    let renderingMode: UIImage.RenderingMode?

    init(
        targetSize: CGSize,
        cornerRadius: CGFloat? = nil,
        tintColor: UIColor? = nil,
        opacity: CGFloat? = nil,
        renderingMode: UIImage.RenderingMode? = nil
    ) {
        self.targetSize = targetSize
        self.cornerRadius = cornerRadius
        self.tintColor = tintColor
        self.opacity = opacity
        self.renderingMode = renderingMode
    }
}

protocol ImageViewModelProtocol {
    func loadImage(
        on imageView: UIImageView,
        settings: ImageViewModelSettings,
        animated: Bool
    )

    func cancel(on imageView: UIImageView)
}

extension ImageViewModelProtocol {
    func loadImage(
        on imageView: UIImageView,
        targetSize: CGSize,
        animated: Bool
    ) {
        let settings = ImageViewModelSettings(
            targetSize: targetSize,
            cornerRadius: nil,
            tintColor: nil,
            renderingMode: nil
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
            tintColor: nil,
            renderingMode: nil
        )

        loadImage(on: imageView, settings: settings, animated: animated)
    }
}
