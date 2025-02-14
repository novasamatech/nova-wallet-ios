import UIKit

extension BannersViewController {
    struct StaticState {
        let currentPage: Int
        let pageByActualOffset: Int
    }

    struct DynamicState {
        let contentOffset: CGFloat
        let pageWidth: CGFloat

        var rawPageIndex: CGFloat {
            contentOffset / pageWidth
        }

        init(
            contentOffset: CGFloat,
            pageWidth: CGFloat
        ) {
            self.contentOffset = contentOffset
            self.pageWidth = pageWidth
        }
    }
}
