import Foundation
import Operation_iOS
import XCTest
@testable import novawallet

struct SubtensorFlowYourBittensor {
    let state: Multistaking.SubtensorStakingState
    let portfolio: SubtensorPortfolio
    let catalogue: SubtensorSubnetsInfo
    let logos: SubtensorSubnetLogoResolver
    let weeklyChanges: [SubtensorSubnetRef: Decimal]
    let monthHistories: [SubtensorSubnetRef: SubtensorPriceHistoryResult]
    let valueSeries: SubtensorPortfolioValueSeries

    func subnetInfo(netuid: UInt16) throws -> SubtensorStakingPallet.DynamicInfo {
        try XCTUnwrap(catalogue.subnets.first { $0.netuid == netuid })
    }

    func subnetRef(netuid: UInt16) throws -> SubtensorSubnetRef {
        SubtensorSubnetRef(netuid: netuid, registeredAt: try subnetInfo(netuid: netuid).networkRegisteredAt)
    }
}

extension SubtensorFlowTestCase {
    func openYourBittensor(in world: SubtensorFlowWorld) throws -> SubtensorFlowYourBittensor {
        let services = world.earnServices
        let priceHistoryService = try XCTUnwrap(services.priceHistoryService)
        let taoPriceId = try XCTUnwrap(world.chainAsset.asset.priceId)

        let state = try awaitPositions(in: world)
        let portfolio = SubtensorPortfolioBuilder.build(state: state)
        let catalogue = try fetchSubnetsInfo(from: world.sharedState.subnetsService)
        let logos = SubtensorSubnetLogoResolver(config: try run(services.earnConfigProvider.createConfigWrapper()))

        let refs = try portfolio.subnets.map { group in
            SubtensorSubnetRef(
                netuid: group.netuid,
                registeredAt: try XCTUnwrap(catalogue.subnets.first { $0.netuid == group.netuid }).networkRegisteredAt
            )
        }

        let weeklyChanges = try run(priceHistoryService.createWeeklyChangesWrapper(for: refs))

        let monthHistories = try refs.reduce(into: [SubtensorSubnetRef: SubtensorPriceHistoryResult]()) { result, ref in
            result[ref] = try run(priceHistoryService.createHistoryWrapper(for: ref, period: .month, currency: .usd))
        }

        let coingeckoOperationFactory = CoingeckoOperationFactory()

        let taoFiatHistory = try withExtendedLifetime(coingeckoOperationFactory) {
            try run(CompoundOperationWrapper(
                targetOperation: coingeckoOperationFactory.fetchPriceHistory(
                    for: taoPriceId,
                    currency: .usd,
                    period: .month
                )
            ))
        }

        let valueSeries = SubtensorPortfolioValueSeriesCalculator.calculate(
            portfolio: portfolio,
            histories: monthHistories.values.compactMap { result in
                guard case let .available(history) = result else {
                    return nil
                }

                return history
            },
            taoFiatHistory: taoFiatHistory,
            period: .month,
            precision: world.chainAsset.asset.decimalPrecision
        )

        return SubtensorFlowYourBittensor(
            state: state,
            portfolio: portfolio,
            catalogue: catalogue,
            logos: logos,
            weeklyChanges: weeklyChanges,
            monthHistories: monthHistories,
            valueSeries: valueSeries
        )
    }

    func assertYourBittensor(_ screen: SubtensorFlowYourBittensor) {
        let chutesRef = SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295)
        let targonRef = SubtensorSubnetRef(netuid: 4, registeredAt: 1_411_451)
        let portfolio = screen.portfolio

        XCTAssertEqual(portfolio.pricedTaoValue, 27_780_759_952)
        XCTAssertEqual(portfolio.unpricedNetuids, [])
        XCTAssertEqual(portfolio.root?.totalAlpha, 20_000_000_000)
        XCTAssertEqual(portfolio.root?.taoValue, 20_000_000_000)
        XCTAssertEqual(portfolio.subnets.map(\.netuid), [64, 4])
        XCTAssertEqual(portfolio.subnets.map(\.totalAlpha), [70_200_000_000, 88_000_000_000])
        XCTAssertEqual(portfolio.subnets.map(\.taoValue), [5_180_760_000, 2_599_999_952])

        XCTAssertEqual(try screen.subnetRef(netuid: 64), chutesRef)
        XCTAssertEqual(try screen.subnetRef(netuid: 4), targonRef)
        XCTAssertEqual(try screen.subnetInfo(netuid: 64).displayName, "Chutes")
        XCTAssertEqual(try screen.subnetInfo(netuid: 64).displaySymbol, "ش")
        XCTAssertEqual(try screen.subnetInfo(netuid: 4).displayName, "Targon")
        XCTAssertEqual(try screen.subnetInfo(netuid: 4).displaySymbol, "δ")

        XCTAssertEqual(screen.logos.url(for: chutesRef)?.absoluteString, SubtensorFlowChainWorld.chutesLogo)
        XCTAssertNil(screen.logos.url(for: targonRef))

        XCTAssertEqual(Array(screen.weeklyChanges.keys), [chutesRef])
        XCTAssertEqual(try flowDouble(screen.weeklyChanges[chutesRef]), 0.0738 / 0.0634 - 1, accuracy: 1e-9)

        guard case let .available(chutesHistory)? = screen.monthHistories[chutesRef] else {
            XCTFail("Expected the Chutes month history, got \(String(describing: screen.monthHistories[chutesRef]))")
            return
        }

        XCTAssertEqual(screen.monthHistories[targonRef], .notListed)
        XCTAssertEqual(chutesHistory.period, .month)
        XCTAssertEqual(chutesHistory.points.map(\.date), [
            SubtensorFlowActiveStake.chartDate(daysBeforeEnd: 30),
            SubtensorFlowActiveStake.chartDate(daysBeforeEnd: 0)
        ])
        assertFlowDoubles(chutesHistory.points.map(\.taoPerAlpha), [0.0634, 0.0738])
        assertFlowDoubles(chutesHistory.points.map(\.fiatPerAlpha), [19.02, 25.2396])
        XCTAssertEqual(try flowDouble(chutesHistory.changeInTao), 0.0738 / 0.0634 - 1, accuracy: 1e-9)
        XCTAssertEqual(try flowDouble(chutesHistory.changeInFiat), 25.2396 / 19.02 - 1, accuracy: 1e-9)

        let series = screen.valueSeries
        XCTAssertEqual(series.points.map(\.date), chutesHistory.points.map(\.date))
        assertFlowDoubles(series.points.map(\.taoValue), [24.45068, 25.18076])
        assertFlowDoubles(series.points.map(\.fiatValue), [7335.204, 8611.81992])
        XCTAssertEqual(try flowDouble(series.changeInTao), 25.18076 / 24.45068 - 1, accuracy: 1e-9)
        XCTAssertEqual(try flowDouble(series.changeInFiat), 8611.81992 / 7335.204 - 1, accuracy: 1e-9)
        XCTAssertEqual(series.netuidsWithoutHistory, [4])
    }

    func flowDouble(_ value: Decimal?) throws -> Double {
        NSDecimalNumber(decimal: try XCTUnwrap(value)).doubleValue
    }

    func assertFlowDoubles(_ values: [Decimal], _ expected: [Double]) {
        XCTAssertEqual(values.count, expected.count)

        for (value, expectedValue) in zip(values, expected) {
            XCTAssertEqual(NSDecimalNumber(decimal: value).doubleValue, expectedValue, accuracy: 1e-9)
        }
    }
}
