import XCTest
@testable import novawallet
import BigInt

final class SwapSetupMaxCorrectionTests: XCTestCase {
    func testDoesNotRequoteWhenFeeLeavesMaxUnchanged() {
        let context = SwapSetupTestContext.make()

        let transferable = context.payAmountInPlank(10)

        context.deliverPayBalance(transferable: transferable)
        context.presenter.selectMaxPayAmount()

        XCTAssertEqual(context.interactor.quoteRequests.count, 1)
        XCTAssertEqual(context.interactor.quoteRequests.last?.amount, transferable)

        context.deliverQuote()

        context.deliverFee(
            submissionAmount: context.payAmountInPlank(1),
            in: CommissionTestFixtures.asset(2)
        )

        XCTAssertEqual(context.interactor.quoteRequests.count, 1)
    }

    func testRequotesWhenFeeReducesMax() {
        let context = SwapSetupTestContext.make()

        let transferable = context.payAmountInPlank(10)
        let feeAmount = context.payAmountInPlank(1)

        context.deliverPayBalance(transferable: transferable)
        context.presenter.selectMaxPayAmount()

        XCTAssertEqual(context.interactor.quoteRequests.count, 1)

        context.deliverQuote()

        context.deliverFee(
            submissionAmount: feeAmount,
            in: context.payChainAsset.chainAssetId
        )

        XCTAssertEqual(context.interactor.quoteRequests.count, 2)
        XCTAssertEqual(context.interactor.quoteRequests.last?.amount, transferable - feeAmount)
    }
}
