import UIKit

enum ImageViewModelFactory {
    static func createAssetIconOrDefault(from url: URL?) -> ImageViewModelProtocol {
        if let assetIconUrl = url {
            return RemoteImageViewModel(url: assetIconUrl)
        } else {
            return StaticImageViewModel(image: R.image.iconDefaultToken()!)
        }
    }
}
