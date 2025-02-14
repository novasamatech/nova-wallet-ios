import UIKit

extension BannersViewController {
    struct StaticState {
        let itemByActualOffset: Int
    }

    struct DynamicState {
        let contentOffset: CGFloat
        let itemWidth: CGFloat

        var rawItemIndex: CGFloat {
            contentOffset / itemWidth
        }

        init(
            contentOffset: CGFloat,
            itemWidth: CGFloat
        ) {
            self.contentOffset = contentOffset
            self.itemWidth = itemWidth
        }
    }
}
