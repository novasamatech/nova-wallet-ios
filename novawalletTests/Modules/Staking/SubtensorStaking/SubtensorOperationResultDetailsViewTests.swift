@testable import novawallet
import UIKit
import XCTest

final class SubtensorOperationResultDetailsViewTests: XCTestCase {
    func testCollapsedSellDetailsFoldOnlyTheirShownRowsUnderTheHeader() {
        let layout = SubtensorOperationResultViewLayout(frame: CGRect(x: 0, y: 0, width: 375, height: 812))
        let shownRowsHeight: CGFloat = 132

        layout.detailsView.bind(viewModel: makeSellProgressDetails(), locale: Locale(identifier: "en"))
        layout.detailsView.setExpanded(false, animated: false)
        layout.layoutIfNeeded()

        XCTAssertEqual(layout.detailsView.contentView.frame.minY, -shownRowsHeight)
        XCTAssertEqual(layout.detailsView.contentView.frame.height, shownRowsHeight)
    }

    private func makeSellProgressDetails() -> SubtensorResultDetailsViewModel {
        SubtensorResultDetailsViewModel(
            title: "Position details",
            swapRate: "1 SN1 ≈ 0.0738 TAO",
            costBasis: nil,
            slippage: nil,
            validator: "Nova Wallet",
            networkFee: BalanceViewModel(amount: "0.0015 TAO", price: "$0.51"),
            isExpanded: false
        )
    }
}
