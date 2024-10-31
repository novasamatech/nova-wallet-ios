import Foundation
import UIKit

enum QRLogoType {
    case remoteColored(URL?)
    case remoteTransparent(URL?)
    case localColored(UIImage)
    case localTransparent(UIImage)

    var url: URL? {
        switch self {
        case let .remoteColored(url), let .remoteTransparent(url):
            return url
        default:
            return nil
        }
    }

    var cacheKey: String? {
        guard let url else { return nil }

        return url.absoluteString + String(describing: self)
    }

    var image: UIImage? {
        switch self {
        case let .localColored(image), let .localTransparent(image):
            return image
        default:
            return nil
        }
    }
}
