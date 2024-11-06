import UIKit

enum ImageViewModelFactory {
    static func createChainIconOrDefault(from url: URL?) -> ImageViewModelProtocol {
        if let chainIconUrl = url {
            return RemoteImageViewModel(url: chainIconUrl)
        } else {
            return StaticImageViewModel(image: R.image.iconNetworkFallback()!)
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
