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
    let stakeHistory: SubtensorPortfolioStakeHistory
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
        let accountSubject = try SubtensorFlowChainWorld.coldkey.toAddress(using: .defaultSubstrateFormat)

        SubtensorFlowURLProtocol.servePortfolioHistoryFixture(accountSubject: accountSubject, period: "THIRTY_DAYS")

        let state = try awaitPositions(in: world)
        let catalogue = try run(services.catalogueService.createCatalogueWrapper())
        let portfolio = SubtensorPortfolioBuilder.build(state: state, catalogue: catalogue)
        let logos = try run(services.subnetLogosProvider.createLogosWrapper())

        let refs = try portfolio.subnets.map { group in
            try XCTUnwrap(catalogue.subnet(for: group.netuid)).ref
        }

        let weeklyPrices = try run(priceHistoryService.createWeeklyChangesWrapper(for: refs))

        let monthHistories = try refs.reduce(into: [SubtensorSubnetRef: SubtensorPriceHistoryResult]()) { result, ref in
            result[ref] = try run(priceHistoryService.createHistoryWrapper(for: ref, period: .month, currency: .usd))
        }

        let stakeHistory = try run(
            services.portfolioHistoryService.createHistoryWrapper(for: accountSubject, period: .month)
        )

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
                stake: stakeHistory
            ),
            currentTaoPrice: 342,
            precision: world.chainAsset.asset.decimalPrecision,
            now: SubtensorFlowActiveStake.chartDate(daysBeforeEnd: 0)
        )

        return SubtensorFlowYourBittensor(
            state: state,
            portfolio: portfolio,
            catalogue: catalogue,
            logos: logos,
            weeklyPrices: weeklyPrices,
            monthHistories: monthHistories,
            stakeHistory: stakeHistory,
            valueSeries: valueSeries
        )
    }

    func assertYourBittensor(_ screen: SubtensorFlowYourBittensor) {
        let chutesRef = SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295)
        let targonRef = SubtensorSubnetRef(netuid: 4, registeredAt: 1_411_451)
        let portfolio = screen.portfolio

        XCTAssertEqual(portfolio.pricedTaoValue, 26_006_407_290)
        XCTAssertEqual(portfolio.unpricedNetuids, [])
        XCTAssertEqual(portfolio.root?.totalAlpha, 20_000_000_000)
        XCTAssertEqual(portfolio.root?.taoValue, 20_000_000_000)
        XCTAssertEqual(portfolio.subnets.map(\.netuid), [64, 4])
        XCTAssertEqual(portfolio.subnets.map(\.totalAlpha), [70_200_000_000, 88_000_000_000])
        XCTAssertEqual(portfolio.subnets.map(\.taoValue), [3_858_278_626, 2_148_128_664])

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
            SubtensorFlowActiveStake.chartDate(daysBeforeEnd: 7),
            SubtensorFlowActiveStake.chartDate(daysBeforeEnd: 0)
        ])
        assertFlowDoubles(chutesHistory.points.map(\.taoPerAlpha), [0.0634, 0.0634, 0.0738])
        assertFlowDoubles(chutesHistory.points.map(\.fiatPerAlpha), [19.02, 19.02, 25.2396])
        XCTAssertEqual(try flowDouble(chutesHistory.changeInTao), 0.0738 / 0.0634 - 1, accuracy: 1e-9)
        XCTAssertEqual(try flowDouble(chutesHistory.changeInFiat), 25.2396 / 19.02 - 1, accuracy: 1e-9)

        let stakeHistory = screen.stakeHistory
        XCTAssertEqual(stakeHistory.period, .month)
        XCTAssertEqual(stakeHistory.windowStart, SubtensorFlowActiveStake.chartDate(daysBeforeEnd: 30))
        XCTAssertEqual(stakeHistory.windowEnd, SubtensorFlowActiveStake.chartDate(daysBeforeEnd: 0))
        XCTAssertEqual(stakeHistory.points.count, 181)
        XCTAssertEqual(stakeHistory.points.last?.isCompleted, false)

        guard let weekStartStake = stakeHistory.points.first(where: {
            $0.date == SubtensorFlowActiveStake.chartDate(daysBeforeEnd: 7)
        }) else {
            XCTFail("Expected a stake sample at the week start")
            return
        }

        // Settled samples are priced by the TAO chart, and the open bucket is replaced by the live total.
        let series = screen.valueSeries
        let weekStartTao = NSDecimalNumber(decimal: weekStartStake.taoValue).doubleValue
        XCTAssertEqual(series.points.map(\.date), [
            SubtensorFlowActiveStake.chartDate(daysBeforeEnd: 30),
            SubtensorFlowActiveStake.chartDate(daysBeforeEnd: 7),
            SubtensorFlowActiveStake.chartDate(daysBeforeEnd: 0)
        ])
        assertFlowDoubles(series.points.map(\.taoValue), [20, weekStartTao, 26.00640729])
        assertFlowDoubles(series.points.map(\.fiatValue), [6000, weekStartTao * 300, 8894.19129318])
        XCTAssertEqual(try flowDouble(series.changeInFiat), 8894.19129318 / 6000 - 1, accuracy: 1e-9)
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
