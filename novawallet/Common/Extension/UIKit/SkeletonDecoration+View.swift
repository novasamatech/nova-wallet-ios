import Foundation
import UIKit_iOS
import UIKit

extension SingleDecoration {
    static func createDecoration(
        on targetView: UIView,
        containerView: UIView,
        spaceSize: CGSize,
        offset: CGPoint,
        size: CGSize
    ) -> SingleDecoration {
        let targetFrame = targetView.convert(targetView.bounds, to: containerView)

        let position = CGPoint(
            x: targetFrame.minX + offset.x + size.width / 2.0,
            y: targetFrame.minY + offset.y + size.height / 2.0
        )

        let mappedSize = CGSize(
            width: spaceSize.skrullMapX(size.width),
            height: spaceSize.skrullMapY(size.height)
        )

        return SingleDecoration(position: spaceSize.skrullMap(point: position), size: mappedSize)
    }
}
