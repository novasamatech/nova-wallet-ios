import Foundation
import UIKit_iOS
import UIKit

extension AssetPriceChartViewLayout {
    struct LoadingState: OptionSet {
        typealias RawValue = UInt8

        static let price = LoadingState(rawValue: 1 << 0)
        static let chart = LoadingState(rawValue: 1 << 1)
        static let all: LoadingState = [.price, .chart]
        static let none: LoadingState = []

        let rawValue: UInt8

        init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
    }
}

extension AssetPriceChartViewLayout: SkeletonableView {
    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        [
            priceLabel,
            priceChangeView,
            currentEntryDateLabel
        ]
    }

    func createSkeletons(for spaceSize: CGSize) -> [any Skeletonable] {
        let priceRows = createSkeletons(
            for: spaceSize,
            lineWidths: Constants.priceSkeletonLineWidths,
            lineHeights: Constants.priceSkeletonLineHeights,
            yOffsets: Constants.priceSkeletonOffsets,
            xOffsets: [0, 0]
        )
        let chartRows = createSkeletons(
            for: spaceSize,
            lineWidths: Constants.chartSkeletonLineWidths,
            lineHeights: Constants.chartSkeletonLineHeights,
            yOffsets: Constants.chartSkeletonOffsets,
            xOffsets: Constants.chartSkeletonLineWidths.map { spaceSize.width - $0 }
        )

        return priceRows + chartRows
    }

    func createSkeletons(
        for spaceSize: CGSize,
        lineWidths: [CGFloat],
        lineHeights: [CGFloat],
        yOffsets: [CGFloat],
        xOffsets: [CGFloat]
    ) -> [any Skeletonable] {
        var lastY: CGFloat = 0

        let rows = zip(
            lineWidths,
            lineHeights
        )
        .enumerated()
        .map { index, size in
            let size = CGSize(
                width: size.0,
                height: size.1
            )

            let yPoint = lastY + yOffsets[index]
            lastY = yPoint + size.height

            let offset = CGPoint(
                x: xOffsets[index],
                y: yPoint
            )

            return SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: offset,
                size: size
            )
        }

        return rows
    }
}
