import UIKit

extension BannersViewController {
    struct StaticState {
        let currentPage: Int
        let pageByActualOffset: Int
    }

    struct DynamicState {
        private let currentPage: Int

        let contentOffset: CGFloat
        let pageWidth: CGFloat

        var rawPageIndex: CGFloat {
            contentOffset / pageWidth
        }

        init(
            contentOffset: CGFloat,
            pageWidth: CGFloat,
            currentPage: Int
        ) {
            self.contentOffset = contentOffset
            self.pageWidth = pageWidth
            self.currentPage = currentPage
        }
    }
}
