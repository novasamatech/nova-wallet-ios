import XCTest
@testable import novawallet
import BigInt

final class SwapIssueViewModelFactoryTests: XCTestCase {
    func testPoolTradeLimitSuppressesTheGenericNoLiquidityIssue() {
        let issues = makeFactory().detectIssues(
            in: makeParams(
                quoteError: makeTradeLimitFailure(maxGivenAmount: 1_000_000, minTradingLimit: 1000)
            ),
            locale: Self.locale
        )

        XCTAssertNotNil(poolTradeLimit(in: issues))
        XCTAssertFalse(issues.contains(.noLiqudity))
    }

    func testCapBelowTheMinimumTradeFallsBackToNoLiquidityRatherThanSuggestingIt() {
        let issues = makeFactory().detectIssues(
            in: makeParams(
                quoteError: makeTradeLimitFailure(maxGivenAmount: 1000, minTradingLimit: 1000)
            ),
            locale: Self.locale
        )

        XCTAssertNil(poolTradeLimit(in: issues))
        XCTAssertTrue(issues.contains(.noLiqudity))
    }

    func testBuyCapIsReportedAgainstTheReceiveField() {
        let issues = makeFactory().detectIssues(
            in: makeParams(
                quoteError: makeTradeLimitFailure(
                    maxGivenAmount: 1_000_000,
                    minTradingLimit: 1000,
                    direction: .buy
                )
            ),
            locale: Self.locale
        )

        XCTAssertEqual(poolTradeLimit(in: issues)?.side, .receive)
    }
}

private extension SwapIssueViewModelFactoryTests {
    static let locale = Locale(identifier: "en_US")

    func makeFactory() -> SwapIssueViewModelFactory {
        SwapIssueViewModelFactory(
            balanceViewModelFactoryFacade: BalanceViewModelFactoryFacade(
                priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
            )
        )
    }

    func makeTradeLimitFailure(
        maxGivenAmount: Balance,
        minTradingLimit: Balance,
        direction: AssetConversion.Direction = .sell
    ) -> AssetExchangeTradeLimitFailure {
        AssetExchangeTradeLimitFailure(
            limitedAsset: CommissionTestFixtures.chainAsset(0),
            maxGivenAmount: maxGivenAmount,
            minTradingLimit: minTradingLimit,
            direction: direction,
            isUserInputAdjustable: true
        )
    }

    func makeParams(quoteError: Error) -> SwapIssueCheckParams {
        SwapIssueCheckParams(
            payChainAsset: nil,
            receiveChainAsset: nil,
            payAmount: nil,
            receiveAmount: nil,
            payAssetBalance: nil,
            receiveAssetBalance: nil,
            payAssetExistense: nil,
            receiveAssetExistense: nil,
            quoteResult: .failure(quoteError),
            fee: nil,
            canApplyPoolTradeLimit: true
        )
    }

    func poolTradeLimit(in issues: [SwapSetupViewIssue]) -> SwapPoolTradeLimitViewModel? {
        issues.compactMap { issue in
            guard case let .poolTradeLimit(viewModel) = issue else {
                return nil
            }

            return viewModel
        }.first
    }
}
