import XCTest
@testable import novawallet
import BigInt

final class HydraExchangeQuoteFactoryTests: XCTestCase {
    func testXYKSellRejectsAnAmountWhosePreFeeOutputBreachesABoundItsQuoteFitsInside() throws {
        let remoteState = HydraXYK.QuoteRemoteState(assetInBalance: 1000, assetOutBalance: 100_000)
        let feeParams = try Self.exchangeFee()

        let quote = try HydraXYKSwapQuoteFactory.calculateSellQuote(
            for: 334,
            remoteState: remoteState,
            feeParams: feeParams,
            ratios: HydraExchangeTradeLimits.Ratios(maxInRatio: 2, maxOutRatio: 1)
        )

        let outRatioBound = try HydraExchangeTradeLimits.bound(
            reserve: remoteState.assetOutBalance,
            ratio: 4
        )

        XCTAssertLessThanOrEqual(quote, outRatioBound)

        assertExceedsPoolTradeLimit(
            try HydraXYKSwapQuoteFactory.calculateSellQuote(
                for: 334,
                remoteState: remoteState,
                feeParams: feeParams,
                ratios: HydraExchangeTradeLimits.Ratios(maxInRatio: 2, maxOutRatio: 4)
            )
        )
    }

    func testXYKBuyAcceptsAnAmountWhosePreFeeInputFitsABoundItsQuoteBreaches() throws {
        let remoteState = HydraXYK.QuoteRemoteState(assetInBalance: 300_000, assetOutBalance: 1_000_000)

        let quote = try HydraXYKSwapQuoteFactory.calculateBuyQuote(
            for: 249_600,
            remoteState: remoteState,
            feeParams: try Self.exchangeFee(),
            ratios: HydraExchangeTradeLimits.Ratios(maxInRatio: 3, maxOutRatio: 3)
        )

        let inRatioBound = try HydraExchangeTradeLimits.bound(
            reserve: remoteState.assetInBalance,
            ratio: 3
        )

        XCTAssertGreaterThan(quote, inRatioBound)
    }

    func testXYKSellRejectsAnAmountInAboveTheBoundOfTheInSideReserve() throws {
        assertExceedsPoolTradeLimit(
            try HydraXYKSwapQuoteFactory.calculateSellQuote(
                for: 1500,
                remoteState: HydraXYK.QuoteRemoteState(assetInBalance: 3000, assetOutBalance: 6000),
                feeParams: try Self.exchangeFee(),
                ratios: HydraExchangeTradeLimits.Ratios(maxInRatio: 3, maxOutRatio: 1)
            )
        )
    }

    func testXYKBuyRejectsAnAmountOutAboveTheBoundOfTheOutSideReserve() throws {
        assertExceedsPoolTradeLimit(
            try HydraXYKSwapQuoteFactory.calculateBuyQuote(
                for: 2001,
                remoteState: HydraXYK.QuoteRemoteState(assetInBalance: 9000, assetOutBalance: 6000),
                feeParams: try Self.exchangeFee(),
                ratios: HydraExchangeTradeLimits.Ratios(maxInRatio: 1, maxOutRatio: 3)
            )
        )
    }

    func testOmnipoolSellQuotesATradeInsideBothBounds() throws {
        let quote = try HydraOmnipoolQuoteFactory.calculateQuote(
            for: .sell,
            args: try Self.omnipoolParams(
                assetInBalance: 3_000_000_000_000,
                assetOutBalance: 9_000_000_000_000
            ),
            amount: 100_000_000_000,
            ratios: HydraExchangeTradeLimits.Ratios(maxInRatio: 3, maxOutRatio: 1)
        )

        XCTAssertGreaterThan(quote, 0)
    }

    func testOmnipoolSellRejectsAnAmountInAboveTheBoundOfTheInSideReserve() throws {
        assertExceedsPoolTradeLimit(
            try HydraOmnipoolQuoteFactory.calculateQuote(
                for: .sell,
                args: try Self.omnipoolParams(
                    assetInBalance: 3_000_000_000_000,
                    assetOutBalance: 9_000_000_000_000
                ),
                amount: 1_000_000_000_001,
                ratios: HydraExchangeTradeLimits.Ratios(maxInRatio: 3, maxOutRatio: 1)
            )
        )
    }

    func testOmnipoolBuyRejectsAnAmountOutAboveTheBoundOfTheOutSideReserve() throws {
        assertExceedsPoolTradeLimit(
            try HydraOmnipoolQuoteFactory.calculateQuote(
                for: .buy,
                args: try Self.omnipoolParams(
                    assetInBalance: 9_000_000_000_000,
                    assetOutBalance: 3_000_000_000_000
                ),
                amount: 1_000_000_000_001,
                ratios: HydraExchangeTradeLimits.Ratios(maxInRatio: 1, maxOutRatio: 3)
            )
        )
    }
}

private extension HydraExchangeQuoteFactoryTests {
    static func exchangeFee(
        nominator: UInt32 = 3,
        denominator: UInt32 = 1000
    ) throws -> HydraXYK.ExchangeFeeParams {
        let json = "[\"\(nominator)\",\"\(denominator)\"]"

        return try JSONDecoder().decode(HydraXYK.ExchangeFeeParams.self, from: Data(json.utf8))
    }

    static func omnipoolParams(
        assetInBalance: Balance,
        assetOutBalance: Balance
    ) throws -> HydraOmnipoolApi.Params {
        HydraOmnipoolApi.Params(
            assetInState: try assetState(reserve: assetInBalance),
            assetOutState: try assetState(reserve: assetOutBalance),
            assetInBalance: assetInBalance,
            assetOutBalance: assetOutBalance,
            assetFee: 0,
            protocolFee: 0,
            maxSlipFee: 0
        )
    }

    static func assetState(reserve: Balance) throws -> HydraOmnipool.AssetState {
        let json = """
        {
            "hubReserve": "\(reserve)",
            "shares": "\(reserve)",
            "protocolShares": "0",
            "tradable": { "bits": "3" }
        }
        """

        return try JSONDecoder().decode(HydraOmnipool.AssetState.self, from: Data(json.utf8))
    }

    func assertExceedsPoolTradeLimit<T>(
        _ expression: @autoclosure () throws -> T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard case HydraExchangeTradeLimitError.exceedsPoolTradeLimit = error else {
                return XCTFail("unexpected error \(error)", file: file, line: line)
            }
        }
    }
}
