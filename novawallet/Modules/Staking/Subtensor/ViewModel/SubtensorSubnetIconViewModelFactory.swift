import Foundation
import UIKit

protocol SubtensorSubnetIconFactoryProtocol {
    func icon(for subnet: SubtensorCatalogueSubnet?, logos: SubtensorSubnetLogos?) -> ImageViewModelProtocol
}

final class SubtensorSubnetIconViewModelFactory {
    private let genericMark: UIImage

    init(genericMark: UIImage = R.image.iconDefaultToken()!) {
        self.genericMark = genericMark
    }
}

extension SubtensorSubnetIconViewModelFactory: SubtensorSubnetIconFactoryProtocol {
    func icon(for subnet: SubtensorCatalogueSubnet?, logos: SubtensorSubnetLogos?) -> ImageViewModelProtocol {
        guard let subnet, let logoUrl = logos?.url(for: subnet.netuid) else {
            return StaticImageViewModel(image: genericMark)
        }

        return RemoteImageViewModel(url: logoUrl, fallbackImage: genericMark)
    }
}
