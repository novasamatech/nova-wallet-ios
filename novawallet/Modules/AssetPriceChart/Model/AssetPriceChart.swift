import UIKit

enum AssetPriceChart {
    struct Colors {
        let chartHighlightedLineColor: UIColor
        let entryDotShadowColor: UIColor
        let changeTextColor: UIColor
    }

    struct Entry {
        let price: Decimal
        let timestamp: Int
    }
}
