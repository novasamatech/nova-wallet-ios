import Foundation
import UIKit_iOS

extension SingleSkeleton {
    static func createRow(
        under targetView: UIView,
        containerView: UIView,
        spaceSize: CGSize,
        offset: CGPoint,
        size: CGSize
    ) -> SingleSkeleton {
        let targetFrame = targetView.convert(targetView.bounds, to: containerView)

        let position = CGPoint(
            x: targetFrame.minX + offset.x + size.width / 2.0,
            y: targetFrame.maxY + offset.y + size.height / 2.0
        )

        let mappedSize = CGSize(
            width: spaceSize.skrullMapX(size.width),
            height: spaceSize.skrullMapY(size.height)
        )

        return SingleSkeleton(position: spaceSize.skrullMap(point: position), size: mappedSize).round()
    }

    static func createRow(
        on targetView: UIView,
        containerView: UIView,
        spaceSize: CGSize,
        offset: CGPoint,
        size: CGSize,
        cornerRadii: CGSize = CGSize(width: 0.5, height: 0.5)
    ) -> SingleSkeleton {
        let targetFrame = targetView.convert(targetView.bounds, to: containerView)

        let position = CGPoint(
            x: targetFrame.minX + offset.x + size.width / 2.0,
            y: targetFrame.minY + offset.y + size.height / 2.0
        )

        let mappedSize = CGSize(
            width: spaceSize.skrullMapX(size.width),
            height: spaceSize.skrullMapY(size.height)
        )

        return SingleSkeleton(position: spaceSize.skrullMap(point: position), size: mappedSize).round(cornerRadii)
    }

    static func createRow(
        above targetView: UIView,
        containerView: UIView,
        spaceSize: CGSize,
        offset: CGPoint,
        size: CGSize
    ) -> SingleSkeleton {
        let targetFrame = targetView.convert(targetView.bounds, to: containerView)

        let position = CGPoint(
            x: targetFrame.minX + offset.x + size.width / 2.0,
            y: targetFrame.minY - offset.y - size.height / 2.0
        )

        let mappedSize = CGSize(
            width: spaceSize.skrullMapX(size.width),
            height: spaceSize.skrullMapY(size.height)
        )

        return SingleSkeleton(position: spaceSize.skrullMap(point: position), size: mappedSize).round()
    }

    static func createRow(
        inPlaceOf targetView: UIView,
        containerView: UIView,
        spaceSize: CGSize,
        size: CGSize
    ) -> SingleSkeleton {
        let targetFrame = targetView.convert(targetView.bounds, to: containerView)

        let position = CGPoint(
            x: targetFrame.minX + size.width / 2.0,
            y: targetFrame.midY
        )

        let mappedSize = CGSize(
            width: spaceSize.skrullMapX(size.width),
            height: spaceSize.skrullMapY(size.height)
        )

        return SingleSkeleton(position: spaceSize.skrullMap(point: position), size: mappedSize).round()
    }
}
