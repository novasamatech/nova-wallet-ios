import Foundation
import UIKit_iOS

enum TokenManageSingleMeasurement {
    static let cellHeight: CGFloat = 52
    static let headerHeight: CGFloat = 40
    static let verticalSpacing: CGFloat = 8

    static func estimatePreferredHeight(for itemsCount: Int) -> CGFloat {
        let height = headerHeight + verticalSpacing + CGFloat(itemsCount) * cellHeight

        return min(height, ModalSheetPresentationConfiguration.maximumContentHeight)
    }
}
