import Foundation
import Operation_iOS
import XCTest
@testable import novawallet

struct SubtensorFlowYourBittensor {
    let state: Multistaking.SubtensorStakingState
    let portfolio: SubtensorPortfolio
    let catalogue: SubtensorSubnetCatalogue
    let logos: SubtensorSubnetLogos
    let weeklyPrices: [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]
    let monthHistories: [SubtensorSubnetRef: SubtensorPriceHistoryResult]
    let valueSeries: SubtensorPortfolioValueSeries

    func subnet(netuid: UInt16) throws -> SubtensorCatalogueSubnet {
        try XCTUnwrap(catalogue.subnet(for: netuid))
    }
}

extension SubtensorFlowTestCase {
    func openYourBittensor(in world: SubtensorFlowWorld) throws -> SubtensorFlowYourBittensor {
        let services = world.earnServices
        let priceHistoryService = try XCTUnwrap(services.priceHistoryService)
        let taoPriceId = try XCTUnwrap(world.chainAsset.asset.priceId)

        let state = try awaitPositions(in: world)
        let portfolio = SubtensorPortfolioBuilder.build(state: state)
        let catalogue = try run(services.catalogueService.createCatalogueWrapper())
        let logos = try run(services.subnetLogosProvider.createLogosWrapper())

        let refs = try portfolio.subnets.map { group in
            try XCTUnwrap(catalogue.subnet(for: group.netuid)).ref
        }

        let weeklyPrices = try run(priceHistoryService.createWeeklyChangesWrapper(for: refs))

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
            histories: SubtensorPortfolioPriceHistories(
                period: .month,
                taoFiat: taoFiatHistory,
                subnets: monthHistories.values.compactMap { result in
                    guard case let .available(history) = result else {
                        return nil
                    }

                    return history
                }
            ),
            currentTaoPrice: 342,
            precision: world.chainAsset.asset.decimalPrecision
        )

        return SubtensorFlowYourBittensor(
            state: state,
            portfolio: portfolio,
            catalogue: catalogue,
            logos: logos,
            weeklyPrices: weeklyPrices,
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

        XCTAssertEqual(try screen.subnet(netuid: 64).ref, chutesRef)
        XCTAssertEqual(try screen.subnet(netuid: 4).ref, targonRef)
        XCTAssertEqual(try screen.subnet(netuid: 64).name, "Chutes")
        XCTAssertEqual(try screen.subnet(netuid: 64).symbol, "ش")
        XCTAssertEqual(try screen.subnet(netuid: 4).name, "Targon")
        XCTAssertEqual(try screen.subnet(netuid: 4).symbol, "δ")

        XCTAssertEqual(screen.logos.url(for: chutesRef.netuid)?.absoluteString, SubtensorFlowChainWorld.chutesLogo)
        XCTAssertNil(screen.logos.url(for: targonRef.netuid))

        XCTAssertEqual(screen.weeklyPrices.count, 2)
        XCTAssertEqual(screen.weeklyPrices[targonRef], .notListed)

        guard case let .available(chutesWeek)? = screen.weeklyPrices[chutesRef] else {
            XCTFail("Expected the Chutes week prices, got \(String(describing: screen.weeklyPrices[chutesRef]))")
            return
        }

        XCTAssertEqual(try flowDouble(chutesWeek.change), 0.0738 / 0.0634 - 1, accuracy: 1e-9)
        assertFlowDoubles(chutesWeek.sparkline, [0.0634, 0.0738])

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
        assertFlowDoubles(series.points.map(\.taoValue), [27.050679952, 27.780759952])
        assertFlowDoubles(series.points.map(\.fiatValue), [8115.2039856, 9501.019903584])
        XCTAssertEqual(try flowDouble(series.changeInFiat), 9501.019903584 / 8115.2039856 - 1, accuracy: 1e-9)
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
