import XCTest
@testable import novawallet
import BigInt

final class HydraFeeOraclePriceCalculatorTests: XCTestCase {
    private let native: HydraDx.AssetId = 0
    private let hub: HydraDx.AssetId = 1

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

    func testEmptyStoredRouteTreatedAsMissing() {
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
            parentBlock: 100
        )

        XCTAssertEqual(price, BigRational(numerator: 1, denominator: 2))
    }

    func testEntryNewerThanParentBlockIsUsedAsStored() {
        let price = HydraFeeOraclePriceCalculator.fastForwardedPrice(
            tenMinutes: entry(1, 2, updatedAt: 120),
            lastBlock: entry(3, 4, updatedAt: 120),
            parentBlock: 100
        )

        XCTAssertEqual(price, BigRational(numerator: 1, denominator: 2))
    }

    func testFastForwardMatchesRuntimeForSmallStaleness() {
        let expected: [BlockNumber: BigUInt] = [
            1: "687302998533380658876519009070106090466",
            2: "693907832240894217916392371708228833912",
            3: "700381877162120379747555370729755087386",
            6: "719044922569713793738782587078022345136"
        ]

        let denominator = BigUInt("1361129467683753853853498429727072845824")

        for (staleBlocks, numerator) in expected {
            let price = HydraFeeOraclePriceCalculator.fastForwardedPrice(
                tenMinutes: entry(1, 2, updatedAt: 100),
                lastBlock: entry(3, 4, updatedAt: 100),
                parentBlock: 100 + staleBlocks
            )

            XCTAssertEqual(
                price,
                BigRational(numerator: numerator, denominator: denominator),
                "mismatch at k = \(staleBlocks)"
            )
        }
    }

    func testFastForwardPastSaturationReturnsLastTradePriceExactly() {
        let price = HydraFeeOraclePriceCalculator.fastForwardedPrice(
            tenMinutes: entry(1, 2, updatedAt: 100),
            lastBlock: entry(3, 4, updatedAt: 100),
            parentBlock: 100 + 4402
        )

        XCTAssertEqual(price, BigRational(numerator: 3, denominator: 4))
    }

    func testLastTradeEntryUpdatedAtIsIgnored() {
        let recent = HydraFeeOraclePriceCalculator.fastForwardedPrice(
            tenMinutes: entry(1, 2, updatedAt: 100),
            lastBlock: entry(3, 4, updatedAt: 100),
            parentBlock: 103
        )

        let stale = HydraFeeOraclePriceCalculator.fastForwardedPrice(
            tenMinutes: entry(1, 2, updatedAt: 100),
            lastBlock: entry(3, 4, updatedAt: 42),
            parentBlock: 103
        )

        XCTAssertEqual(recent, stale)
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
            parentBlock: 100
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
            parentBlock: 100
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
            leg.key(for: .tenMinutes): entry(1, 2, updatedAt: 100),
            leg.key(for: .lastBlock): entry(3, 4, updatedAt: 100)
        ]

        let price = HydraFeeOraclePriceCalculator.routePrice(
            legs: [leg],
            entries: entries,
            parentBlock: 100 + 4402
        )

        XCTAssertEqual(price?.inner, BigRational(numerator: 4, denominator: 3).toFixedU128Inner())
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
            parentBlock: 100
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
            parentBlock: 100
        )

        XCTAssertNil(price)
    }

    func testZeroNumeratorPriceIsAcceptedAndFloorsTheFeeToOnePlank() {
        let leg = HydraFeeOraclePriceCalculator.OracleLeg(
            source: HydraEmaOracle.Source.xyk,
            assetIn: 4,
            assetOut: 9
        )

        let price = HydraFeeOraclePriceCalculator.routePrice(
            legs: [leg],
            entries: [
                leg.key(for: .tenMinutes): entry(0, 7, updatedAt: 100),
                leg.key(for: .lastBlock): entry(0, 7, updatedAt: 100)
            ],
            parentBlock: 100
        )

        XCTAssertEqual(price?.inner, 0)
        XCTAssertEqual(HydraFeeConversion.convertFee(BigUInt("1000000000000"), price: price!), 1)
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
            parentBlock: 100
        )

        XCTAssertNil(price)
    }
}

private extension HydraFeeOraclePriceCalculatorTests {
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
