import XCTest
@testable import novawallet
import BigInt

final class HydraFeeOraclePriceCalculatorTests: XCTestCase {
    private let native: HydraDx.AssetId = 0
    private let hub: HydraDx.AssetId = 1

    private let smoothing = HydraEmaOracle.Smoothing.tenMinutes(blockTimeMillis: 6000)!

    // MARK: - Route resolution

    func testStoredRouteUsedVerbatimWhenRequestedInStoredOrder() {
        let stored = [trade(.omnipool, 0, 7), trade(.xyk, 7, 9)]

        let route = HydraFeeOraclePriceCalculator.resolveRoute(stored: stored, assetIn: 0, assetOut: 9)

        XCTAssertEqual(route.map(hopDescription), ["Omnipool 0->7", "XYK 7->9"])
    }

    func testStoredRouteInvertedWhenRequestedInReverseOrder() {
        let stored = [trade(.omnipool, 0, 7), trade(.xyk, 7, 9)]

        let route = HydraFeeOraclePriceCalculator.resolveRoute(stored: stored, assetIn: 9, assetOut: 0)

        XCTAssertEqual(route.map(hopDescription), ["XYK 9->7", "Omnipool 7->0"])
    }

    func testStableswapPoolIdSurvivesInversion() {
        let stored = [trade(.stableswap(110), 0, 222)]

        let route = HydraFeeOraclePriceCalculator.resolveRoute(stored: stored, assetIn: 222, assetOut: 0)

        guard case let .stableswap(poolId) = route.first?.pool else {
            return XCTFail("expected a stableswap hop")
        }

        XCTAssertEqual(poolId, 110)
        XCTAssertEqual(route.map(hopDescription), ["Stableswap 222->0"])
    }

    func testMissingRouteFallsBackToSingleOmnipoolHopInRequestedOrder() {
        let route = HydraFeeOraclePriceCalculator.resolveRoute(stored: nil, assetIn: 5, assetOut: native)

        XCTAssertEqual(route.map(hopDescription), ["Omnipool 5->0"])
    }

    func testEmptyStoredRouteIsDefendedAgainstWithASingleOmnipoolHop() {
        let route = HydraFeeOraclePriceCalculator.resolveRoute(stored: [], assetIn: 5, assetOut: native)

        XCTAssertEqual(route.map(hopDescription), ["Omnipool 5->0"])
    }

    // MARK: - Oracle legs

    func testOmnipoolHopComposesThroughHub() {
        let legs = HydraFeeOraclePriceCalculator.oracleLegs(for: [trade(.omnipool, 5, 0)], hubAssetId: hub)

        XCTAssertEqual(legs?.map(legDescription), ["omnipool 5->1", "omnipool 1->0"])
    }

    func testOmnipoolHopIntoHubEmitsOnlyOneLeg() {
        let legs = HydraFeeOraclePriceCalculator.oracleLegs(for: [trade(.omnipool, 5, 1)], hubAssetId: hub)

        XCTAssertEqual(legs?.map(legDescription), ["omnipool 5->1"])
    }

    func testStableswapHopComposesThroughPoolShareToken() {
        let legs = HydraFeeOraclePriceCalculator.oracleLegs(
            for: [trade(.stableswap(110), 222, 1003)],
            hubAssetId: hub
        )

        XCTAssertEqual(legs?.map(legDescription), ["stablesw 222->110", "stablesw 110->1003"])
    }

    func testXykHopEmitsOneDirectLeg() {
        let legs = HydraFeeOraclePriceCalculator.oracleLegs(for: [trade(.xyk, 5, 0)], hubAssetId: hub)

        XCTAssertEqual(legs?.map(legDescription), ["hydraxyk 5->0"])
    }

    func testAaveHopEmitsNoLeg() {
        let legs = HydraFeeOraclePriceCalculator.oracleLegs(for: [trade(.aave, 1001, 5)], hubAssetId: hub)

        XCTAssertEqual(legs, [])
    }

    func testLbpHopAbortsThePrice() {
        let legs = HydraFeeOraclePriceCalculator.oracleLegs(
            for: [trade(.omnipool, 5, 0), trade(.lbp, 0, 7)],
            hubAssetId: hub
        )

        XCTAssertNil(legs)
    }

    func testHsmHopAbortsThePrice() {
        let legs = HydraFeeOraclePriceCalculator.oracleLegs(for: [trade(.hsm, 222, 0)], hubAssetId: hub)

        XCTAssertNil(legs)
    }

    // MARK: - Fast forward

    func testEntryUpdatedInParentBlockIsUsedAsStored() {
        let price = HydraFeeOraclePriceCalculator.fastForwardedPrice(
            tenMinutes: entry(1, 2, updatedAt: 100),
            lastBlock: entry(3, 4, updatedAt: 100),
            parentBlock: 100,
            smoothing: smoothing
        )

        XCTAssertEqual(price, BigRational(numerator: 1, denominator: 2))
    }

    func testEntryNewerThanParentBlockIsUsedAsStored() {
        let price = HydraFeeOraclePriceCalculator.fastForwardedPrice(
            tenMinutes: entry(1, 2, updatedAt: 120),
            lastBlock: entry(3, 4, updatedAt: 120),
            parentBlock: 100,
            smoothing: smoothing
        )

        XCTAssertEqual(price, BigRational(numerator: 1, denominator: 2))
    }

    func testFastForwardMovesTowardsTheLastTradePrice() {
        var previous = ratioValue(entry(1, 2, updatedAt: 100), lastBlock: entry(3, 4, updatedAt: 100), at: 100)

        for staleBlocks in [BlockNumber(1), 2, 3, 6, 50] {
            let value = ratioValue(
                entry(1, 2, updatedAt: 100),
                lastBlock: entry(3, 4, updatedAt: 100),
                at: 100 + staleBlocks
            )

            XCTAssertGreaterThan(value, previous, "not monotonic at k = \(staleBlocks)")
            XCTAssertLessThan(value, 0.75)

            previous = value
        }
    }

    func testFastForwardUsesTheConfiguredSmoothing() {
        let value = ratioValue(
            entry(1, 2, updatedAt: 100),
            lastBlock: entry(3, 4, updatedAt: 100),
            at: 101
        )

        XCTAssertEqual(value, 0.5 + 0.25 * 2.0 / 101.0, accuracy: 1e-12)
    }

    func testFastForwardPastSaturationReturnsLastTradePriceExactly() {
        let price = HydraFeeOraclePriceCalculator.fastForwardedPrice(
            tenMinutes: entry(1, 2, updatedAt: 100),
            lastBlock: entry(3, 4, updatedAt: 100),
            parentBlock: 100 + 4402,
            smoothing: smoothing
        )

        XCTAssertEqual(ratioValue(price), 0.75, accuracy: 1e-15)
    }

    func testLastTradeEntryUpdatedAtIsIgnored() {
        let recent = HydraFeeOraclePriceCalculator.fastForwardedPrice(
            tenMinutes: entry(1, 2, updatedAt: 100),
            lastBlock: entry(3, 4, updatedAt: 100),
            parentBlock: 103,
            smoothing: smoothing
        )

        let stale = HydraFeeOraclePriceCalculator.fastForwardedPrice(
            tenMinutes: entry(1, 2, updatedAt: 100),
            lastBlock: entry(3, 4, updatedAt: 42),
            parentBlock: 103,
            smoothing: smoothing
        )

        XCTAssertEqual(ratioValue(recent), ratioValue(stale), accuracy: 1e-15)
    }

    // MARK: - Route price

    func testRoutePriceComposesLegsAndQuantises() {
        let legs = HydraFeeOraclePriceCalculator.oracleLegs(for: [trade(.omnipool, 5, 9)], hubAssetId: 7)!

        XCTAssertEqual(legs.map(\.isInverted), [false, false])

        let entries = [
            legs[0].key(for: .tenMinutes): entry(2, 1, updatedAt: 100),
            legs[0].key(for: .lastBlock): entry(2, 1, updatedAt: 100),
            legs[1].key(for: .tenMinutes): entry(3, 5, updatedAt: 100),
            legs[1].key(for: .lastBlock): entry(3, 5, updatedAt: 100)
        ]

        let price = HydraFeeOraclePriceCalculator.routePrice(
            legs: legs,
            entries: entries,
            parentBlock: 100,
            smoothing: smoothing
        )

        XCTAssertEqual(price?.inner, BigUInt("1200000000000000000"))
        XCTAssertEqual(
            HydraFeeConversion.convertFee(BigUInt("1000000000000"), price: price!),
            BigUInt("1200000000000")
        )
    }

    func testRoutePriceInvertsEveryDescendingLeg() {
        let legs = HydraFeeOraclePriceCalculator.oracleLegs(for: [trade(.omnipool, 5, 0)], hubAssetId: hub)!

        XCTAssertEqual(legs.map(\.isInverted), [true, true])

        let entries = [
            legs[0].key(for: .tenMinutes): entry(2, 1, updatedAt: 100),
            legs[0].key(for: .lastBlock): entry(2, 1, updatedAt: 100),
            legs[1].key(for: .tenMinutes): entry(3, 5, updatedAt: 100),
            legs[1].key(for: .lastBlock): entry(3, 5, updatedAt: 100)
        ]

        let price = HydraFeeOraclePriceCalculator.routePrice(
            legs: legs,
            entries: entries,
            parentBlock: 100,
            smoothing: smoothing
        )

        XCTAssertEqual(price?.inner, BigUInt("833333333333333333"))
        XCTAssertEqual(
            HydraFeeConversion.convertFee(BigUInt("1000000000000"), price: price!),
            BigUInt("833333333333")
        )
    }

    func testLegIsInvertedAfterTheFastForward() {
        let leg = HydraFeeOraclePriceCalculator.OracleLeg(
            source: HydraEmaOracle.Source.xyk,
            assetIn: 9,
            assetOut: 4
        )

        let entries = [
            leg.key(for: .tenMinutes): entry(1, 1, updatedAt: 100),
            leg.key(for: .lastBlock): entry(3, 1, updatedAt: 100)
        ]

        let price = HydraFeeOraclePriceCalculator.routePrice(
            legs: [leg],
            entries: entries,
            parentBlock: 101,
            smoothing: smoothing
        )

        XCTAssertEqual(priceValue(price), 1.0 / (1.0 + 2.0 / 101.0 * 2.0), accuracy: 1e-12)
    }

    func testAaveOnlyRouteIsPricedOneToOne() {
        let legs = HydraFeeOraclePriceCalculator.oracleLegs(for: [trade(.aave, 1001, 5)], hubAssetId: hub)

        XCTAssertEqual(legs, [])

        let price = HydraFeeOraclePriceCalculator.routePrice(
            legs: legs!,
            entries: [:],
            parentBlock: 100,
            smoothing: smoothing
        )

        XCTAssertEqual(price, .one)
        XCTAssertEqual(
            HydraFeeConversion.convertFee(BigUInt("1000000000000"), price: price!),
            BigUInt("1000000000000")
        )
    }

    func testZeroNumeratorPriceOnADescendingLegStaysZeroRatherThanInverting() {
        let leg = HydraFeeOraclePriceCalculator.OracleLeg(
            source: HydraEmaOracle.Source.xyk,
            assetIn: 9,
            assetOut: 4
        )

        XCTAssertTrue(leg.isInverted)

        let price = HydraFeeOraclePriceCalculator.routePrice(
            legs: [leg],
            entries: [
                leg.key(for: .tenMinutes): entry(0, 7, updatedAt: 100),
                leg.key(for: .lastBlock): entry(0, 7, updatedAt: 100)
            ],
            parentBlock: 100,
            smoothing: smoothing
        )

        XCTAssertEqual(price?.inner, 0)
        XCTAssertEqual(HydraFeeConversion.convertFee(BigUInt("1000000000000"), price: price!), 1)
    }

    func testMissingLastTradeEntryFailsEvenWhenThePeriodEntryExists() {
        let leg = HydraFeeOraclePriceCalculator.OracleLeg(
            source: HydraEmaOracle.Source.xyk,
            assetIn: 4,
            assetOut: 9
        )

        let price = HydraFeeOraclePriceCalculator.routePrice(
            legs: [leg],
            entries: [leg.key(for: .tenMinutes): entry(1, 2, updatedAt: 100)],
            parentBlock: 100,
            smoothing: smoothing
        )

        XCTAssertNil(price)
    }

    func testMissingPeriodEntryFails() {
        let leg = HydraFeeOraclePriceCalculator.OracleLeg(
            source: HydraEmaOracle.Source.xyk,
            assetIn: 4,
            assetOut: 9
        )

        let price = HydraFeeOraclePriceCalculator.routePrice(
            legs: [leg],
            entries: [leg.key(for: .lastBlock): entry(1, 2, updatedAt: 100)],
            parentBlock: 100,
            smoothing: smoothing
        )

        XCTAssertNil(price)
    }

    func testZeroDenominatorPriceIsUnavailable() {
        let leg = HydraFeeOraclePriceCalculator.OracleLeg(
            source: HydraEmaOracle.Source.xyk,
            assetIn: 4,
            assetOut: 9
        )

        let price = HydraFeeOraclePriceCalculator.routePrice(
            legs: [leg],
            entries: [
                leg.key(for: .tenMinutes): entry(1, 0, updatedAt: 100),
                leg.key(for: .lastBlock): entry(1, 0, updatedAt: 100)
            ],
            parentBlock: 100,
            smoothing: smoothing
        )

        XCTAssertNil(price)
    }
}

extension HydraFeeOraclePriceCalculatorTests {
    func testSmoothingMatchesTheOraclePalletAtSixSecondBlocks() {
        XCTAssertEqual(
            HydraEmaOracle.Smoothing.tenMinutes(blockTimeMillis: 6000),
            BigUInt("3369132345751865974884897103284833777")
        )
    }

    func testSmoothingMatchesTheOraclePalletAtTwoSecondBlocks() {
        XCTAssertEqual(
            HydraEmaOracle.Smoothing.tenMinutes(blockTimeMillis: 2000),
            BigUInt("1130506202395144396888287732331455852")
        )
    }
}

private extension HydraFeeOraclePriceCalculatorTests {
    func priceValue(_ price: HydraFeeConversion.Price?) -> Double {
        guard let price else {
            return .nan
        }

        return Double(price.inner.description)! / Double(HydraFeeConversion.Price.divisor.description)!
    }

    func ratioValue(_ ratio: BigRational?) -> Double {
        guard let ratio, ratio.denominator > 0 else {
            return .nan
        }

        return Double(ratio.numerator.description)! / Double(ratio.denominator.description)!
    }

    func ratioValue(
        _ tenMinutes: HydraEmaOracle.Entry,
        lastBlock: HydraEmaOracle.Entry,
        at parentBlock: BlockNumber
    ) -> Double {
        ratioValue(
            HydraFeeOraclePriceCalculator.fastForwardedPrice(
                tenMinutes: tenMinutes,
                lastBlock: lastBlock,
                parentBlock: parentBlock,
                smoothing: smoothing
            )
        )
    }

    func trade(
        _ pool: HydraRouter.PoolType,
        _ assetIn: HydraDx.AssetId,
        _ assetOut: HydraDx.AssetId
    ) -> HydraRouter.Trade {
        HydraRouter.Trade(pool: pool, assetIn: assetIn, assetOut: assetOut)
    }

    func entry(
        _ numerator: BigUInt,
        _ denominator: BigUInt,
        updatedAt: BlockNumber
    ) -> HydraEmaOracle.Entry {
        HydraEmaOracle.Entry(
            price: HydraEmaOracle.Ratio(numerator: numerator, denominator: denominator),
            updatedAt: updatedAt
        )
    }

    func hopDescription(_ trade: HydraRouter.Trade) -> String {
        let pool: String

        switch trade.pool {
        case .xyk: pool = HydraRouter.PoolType.xykField
        case .lbp: pool = HydraRouter.PoolType.lbpField
        case .stableswap: pool = HydraRouter.PoolType.stableswapField
        case .omnipool: pool = HydraRouter.PoolType.omnipoolField
        case .aave: pool = HydraRouter.PoolType.aaveField
        case .hsm: pool = HydraRouter.PoolType.hsmField
        }

        return "\(pool) \(trade.assetIn)->\(trade.assetOut)"
    }

    func legDescription(_ leg: HydraFeeOraclePriceCalculator.OracleLeg) -> String {
        let source = String(data: leg.source, encoding: .utf8) ?? "?"

        return "\(source) \(leg.assetIn)->\(leg.assetOut)"
    }
}
