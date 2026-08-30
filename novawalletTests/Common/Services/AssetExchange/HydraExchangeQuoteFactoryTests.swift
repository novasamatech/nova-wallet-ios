import XCTest
@testable import novawallet
import BigInt

final class HydraExchangeQuoteFactoryTests: XCTestCase {
    func testXYKSellWithinBothRatiosIsWithinLimit() throws {
        let verdict = try HydraXYKSwapQuoteFactory.tradeLimitVerdict(
            for: 100,
            direction: .sell,
            remoteState: HydraXYK.QuoteRemoteState(assetInBalance: 1000, assetOutBalance: 100_000),
            limits: Self.limits(maxInRatio: 3, maxOutRatio: 3)
        )

        XCTAssertEqual(verdict, .withinLimit)
    }

    func testXYKSellRejectsAnAmountWhosePreFeeOutputBreachesABoundItsQuoteFitsInside() throws {
        let verdict = try HydraXYKSwapQuoteFactory.tradeLimitVerdict(
            for: 334,
            direction: .sell,
            remoteState: HydraXYK.QuoteRemoteState(assetInBalance: 1000, assetOutBalance: 100_000),
            limits: Self.limits(maxInRatio: 2, maxOutRatio: 4)
        )

        XCTAssertEqual(verdict, .exceeds(.init(maxGivenAmount: 333, minTradingLimit: nil)))
    }

    func testXYKBuyPoolMathRoundsUpIntoRejectionAtTheAmountAndroidsFloorCapAccepts() throws {
        let remoteState = HydraXYK.QuoteRemoteState(assetInBalance: 3000, assetOutBalance: 1000)
        let limits = Self.limits(maxInRatio: 3, maxOutRatio: 3)

        let accepted = try HydraXYKSwapQuoteFactory.tradeLimitVerdict(
            for: 249,
            direction: .buy,
            remoteState: remoteState,
            limits: limits
        )

        XCTAssertEqual(accepted, .withinLimit)

        let rejected = try HydraXYKSwapQuoteFactory.tradeLimitVerdict(
            for: 250,
            direction: .buy,
            remoteState: remoteState,
            limits: limits
        )

        XCTAssertEqual(rejected, .exceeds(.init(maxGivenAmount: 249, minTradingLimit: nil)))
    }

    func testXYKVerdictCarriesTheMinTradingLimitItWasGiven() throws {
        let verdict = try HydraXYKSwapQuoteFactory.tradeLimitVerdict(
            for: 334,
            direction: .sell,
            remoteState: HydraXYK.QuoteRemoteState(assetInBalance: 1000, assetOutBalance: 100_000),
            limits: HydraExchangeTradeLimits.PoolLimits(
                maxInRatio: 2,
                maxOutRatio: 4,
                minTradingLimit: 1000
            )
        )

        XCTAssertEqual(verdict, .exceeds(.init(maxGivenAmount: 333, minTradingLimit: 1000)))
    }

    func testXYKVerdictNamesNoAssetBeforeAnEdgeSeesIt() throws {
        let verdict = try HydraXYKSwapQuoteFactory.tradeLimitVerdict(
            for: 334,
            direction: .sell,
            remoteState: HydraXYK.QuoteRemoteState(assetInBalance: 1000, assetOutBalance: 100_000),
            limits: Self.limits(maxInRatio: 2, maxOutRatio: 4)
        )

        guard case let .exceeds(breach) = verdict else {
            return XCTFail("expected a breach")
        }

        XCTAssertNil(breach.limitedAsset)
    }
}

private extension HydraExchangeQuoteFactoryTests {
    static func limits(maxInRatio: Balance, maxOutRatio: Balance) -> HydraExchangeTradeLimits.PoolLimits {
        HydraExchangeTradeLimits.PoolLimits(
            maxInRatio: maxInRatio,
            maxOutRatio: maxOutRatio,
            minTradingLimit: nil
        )
    }
}
