import Foundation
import UIKit
import UIKit_iOS

enum ChainAddressDetailsMeasurement {
    static let iconViewSize: CGFloat = 88.0
    static let iconContentInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

    static var iconSize: CGSize {
        CGSize(
            width: iconViewSize - iconContentInsets.left - iconContentInsets.right,
            height: iconViewSize - iconContentInsets.top - iconContentInsets.bottom
        )
    }

    static let networkTitleHeight: CGFloat = 24.0

    static let textTitleHeight: CGFloat = 22.0

    static let cellHeight: CGFloat = 48.0

    static let headerSpacing: CGFloat = 16.0
    static let headerBottomInset: CGFloat = 4.0

    static func measureNetworkTitlePreferredHeight(for actionsCount: Int, hasAddress: Bool) -> CGFloat {
        measurePreferredHeight(for: actionsCount, titleHeight: networkTitleHeight, hasAddress: hasAddress)
    }

    static func measureTextTitlePreferredHeight(for actionsCount: Int, hasAddress: Bool) -> CGFloat {
        measurePreferredHeight(for: actionsCount, titleHeight: textTitleHeight, hasAddress: hasAddress)
    }

    static func measurePreferredHeight(for actionsCount: Int, titleHeight: CGFloat, hasAddress: Bool) -> CGFloat {
        let addressHeight: CGFloat = hasAddress ? 36.0 : 0.0
        let cellsHeight = cellHeight * CGFloat(actionsCount)

        let calculatedHeight = titleHeight + headerSpacing + iconViewSize + headerSpacing +
            addressHeight + headerBottomInset + cellsHeight

        let maxHeight = ModalSheetPresentationConfiguration.maximumContentHeight

        return min(maxHeight, calculatedHeight)
    }
}
