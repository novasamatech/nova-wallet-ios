import Foundation
import UIKit

struct QRLogoInfo {
    let size: CGSize
    let type: QRLogoType?

    var url: URL? {
        type?.url
    }

    func byChangingToLocal(_ image: UIImage) -> QRLogoInfo? {
        switch type {
        case .remoteColored:
            QRLogoInfo(
                size: size,
                type: .localColored(image)
            )
        case .remoteTransparent:
            QRLogoInfo(
                size: size,
                type: .localTransparent(image)
            )
        default:
            QRLogoInfo(
                size: size,
                type: nil
            )
        }
    }

    func withNoLogo() -> QRLogoInfo {
        QRLogoInfo(
            size: size,
            type: nil
        )
    }
}
