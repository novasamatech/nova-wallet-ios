import Foundation
import UIKit

struct IconInfo {
    let size: CGSize
    let type: IconType?

    var url: URL? {
        type?.url
    }

    func byChangingToLocal(_ image: UIImage) -> IconInfo? {
        switch type {
        case .remoteColored:
            IconInfo(
                size: size,
                type: .localColored(image)
            )
        case .remoteTransparent:
            IconInfo(
                size: size,
                type: .localTransparent(image)
            )
        default:
            IconInfo(
                size: size,
                type: nil
            )
        }
    }

    func withNoLogo() -> IconInfo {
        IconInfo(
            size: size,
            type: nil
        )
    }
}
