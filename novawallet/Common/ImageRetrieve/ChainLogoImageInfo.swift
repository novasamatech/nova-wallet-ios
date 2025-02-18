import Foundation
import UIKit

struct ChainLogoImageInfo {
    let size: CGSize
    let scale: CGFloat
    let type: IconType?

    var url: URL? {
        type?.url
    }

    var scaledSize: CGSize {
        CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
    }

    func byChangingToLocal(_ image: UIImage) -> ChainLogoImageInfo? {
        switch type {
        case .remoteColored:
            ChainLogoImageInfo(
                size: size,
                scale: scale,
                type: .localColored(image)
            )
        case .remoteTransparent:
            ChainLogoImageInfo(
                size: size,
                scale: scale,
                type: .localTransparent(image)
            )
        default:
            ChainLogoImageInfo(
                size: size,
                scale: scale,
                type: nil
            )
        }
    }

    func withNoLogo() -> ChainLogoImageInfo {
        ChainLogoImageInfo(
            size: size,
            scale: scale,
            type: nil
        )
    }
}
