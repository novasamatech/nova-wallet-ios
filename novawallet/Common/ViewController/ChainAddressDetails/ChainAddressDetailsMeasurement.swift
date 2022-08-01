import Foundation
import UIKit

enum ChainAddressDetailsMeasurement {
    static let iconViewSize: CGFloat = 88.0
    static let iconContentInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

    static var iconSize: CGSize {
        CGSize(
            width: iconViewSize - iconContentInsets.left - iconContentInsets.right,
            height: iconViewSize - iconContentInsets.top - iconContentInsets.bottom
        )
    }

    static let networkHeight: CGFloat = 24.0

    static let cellHeight: CGFloat = 48.0

    static let headerSpacing: CGFloat = 16.0
    static let headerBottomInset: CGFloat = 4.0

    static func measurePreferredHeight(for actionsCount: Int, hasAddress: Bool) -> CGFloat {
        let addressHeight: CGFloat = hasAddress ? 36.0 : 0.0
        let cellsHeight = cellHeight * CGFloat(actionsCount)

        let calculatedHeight = networkHeight + headerSpacing + iconViewSize + headerSpacing +
            addressHeight + headerBottomInset + cellsHeight

        let maxHeight = UIScreen.main.bounds.height * 0.75

        return min(maxHeight, calculatedHeight)
    }
}
