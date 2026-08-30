import XCTest
@testable import novawallet
import BigInt

final class SwapPoolTradeLimitReportingTests: XCTestCase {
    func testSuggestionUndershootsTheExactCapByTheAndroidHeadroom() {
        let failure = Self.failure(maxGivenAmount: 1_000_000, direction: .sell)

        XCTAssertEqual(failure.suggestion(), 950_000)
    }

    func testBuySuggestionSurvivesTheCommissionGrossUp() throws {
        let failure = Self.failure(maxGivenAmount: 1_000_000, direction: .buy)

        let suggestion = try XCTUnwrap(failure.suggestion())
        let rate = AssetExchangeCommissionConstants.rate
        let grossedUp = suggestion + rate.mul(value: suggestion)

        XCTAssertLessThanOrEqual(grossedUp, failure.maxGivenAmount)
    }

    func testSuggestionBelowTheMinimumTradingLimitIsNotOffered() {
        let failure = Self.failure(maxGivenAmount: 1000, minTradingLimit: 2000, direction: .sell)

        XCTAssertNil(failure.suggestion())
    }

    func testCapOfZeroIsNotOffered() {
        let failure = Self.failure(maxGivenAmount: 0, direction: .sell)

        XCTAssertNil(failure.suggestion())
    }

    func testCorrectionBudgetIsExhaustedAfterItsLimit() {
        var counter = MaxCounter.feeCorrection()

        while counter.incrementCounterIfPossible() {}

        XCTAssertFalse(counter.hasBudget())

        counter.resetCounter()

        XCTAssertTrue(counter.hasBudget())
    }
}

private extension SwapPoolTradeLimitReportingTests {
    static func failure(
        maxGivenAmount: Balance,
        minTradingLimit: Balance? = nil,
        direction: AssetConversion.Direction
    ) -> AssetExchangeTradeLimitFailure {
        AssetExchangeTradeLimitFailure(
            limitedAsset: {
                let chain = ChainModelGenerator.generateChain(generatingAssets: 2, addressPrefix: 0)

                return ChainAsset(chain: chain, asset: chain.utilityAssets().first!)
            }(),
            maxGivenAmount: maxGivenAmount,
            minTradingLimit: minTradingLimit,
            direction: direction,
            isUserInputAdjustable: true
        )
    }
}
