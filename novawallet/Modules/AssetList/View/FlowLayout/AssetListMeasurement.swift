import UIKit

enum AssetListMeasurement {
    static var totalBalanceHeight: CGFloat {
        // TODO: Remove conditional compilation on cards release
        #if F_RELEASE
            260.0 - 58.0 // cardView height
        #else
            260.0
        #endif
    }

    static let totalBalanceWithLocksHeight: CGFloat = totalBalanceHeight

    static let settingsHeight: CGFloat = 56.0
    static let nftsHeight = 56.0
    static let bannerHeight = 102.0
    static let assetHeight: CGFloat = 56.0
    static let assetHeaderHeight: CGFloat = 45.0
    static let emptyStateCellHeight: CGFloat = 230
    static let decorationInset: CGFloat = 8.0
    static let promotionInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0.0, right: 0)
    static let summaryInsets = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
    static let nftsInsets = UIEdgeInsets(top: 0, left: 0, bottom: 4, right: 0)
    static let settingsInsets = UIEdgeInsets.zero
    static let assetGroupInsets = UIEdgeInsets(top: 0.0, left: 0, bottom: 16.0, right: 0)

    static let underneathViewHeight: CGFloat = 4
    static let decorationContentInset: CGFloat = 4
}
