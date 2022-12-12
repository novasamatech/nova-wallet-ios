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

enum ImageViewModelFactory {
    static func createAssetIconOrDefault(from url: URL?) -> ImageViewModelProtocol {
        if let assetIconUrl = url {
            return RemoteImageViewModel(url: assetIconUrl)
        } else {
            return StaticImageViewModel(image: R.image.iconDefaultToken()!)
        }
    }
}
