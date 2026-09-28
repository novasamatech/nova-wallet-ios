import Foundation
import UIKit

protocol SubtensorSubnetIconFactoryProtocol {
    func icon(for subnet: SubtensorCatalogueSubnet?, config: SubtensorEarnConfig?) -> ImageViewModelProtocol
}

final class SubtensorSubnetIconViewModelFactory {
    private let genericMark: UIImage

    init(genericMark: UIImage = R.image.iconDefaultToken()!) {
        self.genericMark = genericMark
    }
}

extension SubtensorSubnetIconViewModelFactory: SubtensorSubnetIconFactoryProtocol {
    func icon(for subnet: SubtensorCatalogueSubnet?, config: SubtensorEarnConfig?) -> ImageViewModelProtocol {
        guard
            let subnet,
            let config,
            let logoUrl = SubtensorSubnetLogoResolver(config: config).url(for: subnet.ref) else {
            return StaticImageViewModel(image: genericMark)
        }

        return RemoteImageViewModel(url: logoUrl, fallbackImage: genericMark)
    }
}
