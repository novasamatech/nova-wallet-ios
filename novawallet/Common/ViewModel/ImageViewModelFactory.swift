import UIKit

enum ImageViewModelFactory {
    static func createAssetIconOrDefault(from url: URL?) -> ImageViewModelProtocol {
        if let assetIconUrl = url {
            return RemoteImageViewModel(url: assetIconUrl)
        } else {
            return StaticImageViewModel(image: R.image.iconDefaultToken()!)
        }
    }
    
    static func createChainIconOrDefault(from url: URL?) -> ImageViewModelProtocol {
        if let chainIconUrl = url {
            return RemoteImageViewModel(url: chainIconUrl)
        } else {
            return StaticImageViewModel(image: R.image.iconDefaultToken()!)
        }
    }
    
    static func createIdentifiableChainIcon(from url: URL?) -> IdentifiableImageViewModelProtocol? {
        if let chainIconUrl = url {
            return RemoteImageViewModel(url: chainIconUrl)
        } else {
            return nil
        }
    }
}
