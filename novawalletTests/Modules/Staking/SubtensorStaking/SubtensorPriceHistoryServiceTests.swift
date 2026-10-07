import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorPriceHistoryServiceTests: XCTestCase {
    private let taoPriceId = "bittensor"
    private let now: TimeInterval = 1_790_208_000
    private let chutes = SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295)
    private let templar = SubtensorSubnetRef(netuid: 3, registeredAt: 3_989_825)
    private let unlisted = SubtensorSubnetRef(netuid: 7, registeredAt: 2_000_000)

    func testHistoryDividesAlphaFiatByTaoFiatAtTheNearestTimestamp() throws {
        let coingecko = MockCoingeckoOperationFactoryProtocol()

        stubCharts(coingecko, [
            taoPriceId: [(1000, "400"), (4600, "0"), (606_000, "500"), (609_600, "520")],
            "chutes": [(1120, "20"), (4600, "30"), (608_000, "26"), (617_800, "25")]
        ])

        let result = try run(makeService(coingecko: coingecko).createHistoryWrapper(
            for: chutes,
            period: .week,
            currency: .usd
        ))

        let expected = try SubtensorPriceHistory(
            subnet: chutes,
            period: .week,
            points: [
                point(1120, taoPerAlpha: "0.05", fiatPerAlpha: "20"),
                point(608_000, taoPerAlpha: "0.05", fiatPerAlpha: "26")
            ],
            changeInTao: 0,
            changeInFiat: XCTUnwrap(Decimal(string: "0.3"))
        )

        XCTAssertEqual(result, .available(expected))
        verify(coingecko).fetchPriceHistory(
            for: equal(to: "chutes"),
            currency: equal(to: Currency.usd),
            period: equal(to: PriceHistoryPeriod.week)
        )

        verify(coingecko).fetchPriceHistory(
            for: equal(to: taoPriceId),
            currency: equal(to: Currency.usd),
            period: equal(to: PriceHistoryPeriod.week)
        )
    }

    func testHistoryIsNotListedWhenTheMarketsHaveNoCoinForTheNetuid() throws {
        let coingecko = MockCoingeckoOperationFactoryProtocol()
        stubCharts(coingecko, [:])

        let service = makeService(
            coingecko: coingecko,
            markets: SubtensorSubnetMarkets(byNetuid: [templar.netuid: market("templar", change: -12)])
        )

        let result = try run(service.createHistoryWrapper(for: chutes, period: .week, currency: .usd))

        XCTAssertEqual(result, .notListed)
        verify(coingecko, never()).fetchPriceHistory(for: any(), currency: any(), period: any())
    }

    func testQuarterHistorySlicesTheYearSeriesToItsLastThreeMonths() throws {
        let coingecko = MockCoingeckoOperationFactoryProtocol()

        stubCharts(coingecko, [
            taoPriceId: [
                (1_777_593_600, "400"), (1_782_172_800, "400"), (1_782_259_200, "400"),
                (1_785_542_400, "400"), (1_790_208_000, "400")
            ],
            "chutes": [
                (1_777_593_600, "10"), (1_782_172_800, "12"), (1_782_259_200, "16"),
                (1_785_542_400, "20"), (1_790_208_000, "24")
            ]
        ])

        let result = try run(makeService(coingecko: coingecko).createHistoryWrapper(
            for: chutes,
            period: .quarter,
            currency: .usd
        ))

        let expected = try SubtensorPriceHistory(
            subnet: chutes,
            period: .quarter,
            points: [
                point(1_782_259_200, taoPerAlpha: "0.04", fiatPerAlpha: "16"),
                point(1_785_542_400, taoPerAlpha: "0.05", fiatPerAlpha: "20"),
                point(1_790_208_000, taoPerAlpha: "0.06", fiatPerAlpha: "24")
            ],
            changeInTao: XCTUnwrap(Decimal(string: "0.5")),
            changeInFiat: XCTUnwrap(Decimal(string: "0.5"))
        )

        XCTAssertEqual(result, .available(expected))
        verify(coingecko, times(2)).fetchPriceHistory(
            for: any(),
            currency: any(),
            period: equal(to: PriceHistoryPeriod.year)
        )
    }

    func testHistoryFailsWhenTheTaoSeriesFails() {
        let coingecko = MockCoingeckoOperationFactoryProtocol()

        stubCharts(coingecko, ["chutes": [(1000, "20")]])

        XCTAssertThrowsError(try run(makeService(coingecko: coingecko).createHistoryWrapper(
            for: chutes,
            period: .day,
            currency: .usd
        ))) { error in
            guard case CommonError.dataCorruption = error else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    func testWeeklyPricesComeFromTheMarketsRelativeToTheTaoWeek() throws {
        let coingecko = MockCoingeckoOperationFactoryProtocol()
        let celium = SubtensorSubnetRef(netuid: 51, registeredAt: 5_021_873)

        stubCharts(coingecko, [taoPriceId: [(0, "400"), (604_800, "440")]])

        let markets = SubtensorSubnetMarkets(byNetuid: [
            chutes.netuid: market("chutes", change: 32, sparkline: [22, nil, 33]),
            templar.netuid: market("templar", change: -12),
            celium.netuid: market("celium", change: nil)
        ])

        let prices = try run(makeService(coingecko: coingecko, markets: markets).createWeeklyChangesWrapper(
            for: [chutes, templar, celium, unlisted]
        ))

        XCTAssertEqual(prices, try [
            chutes: .available(SubtensorWeeklyPriceSummary(
                change: decimal("0.2"),
                sparkline: [decimal("0.055"), decimal("0.075")]
            )),
            templar: .available(SubtensorWeeklyPriceSummary(change: decimal("-0.2"), sparkline: [])),
            celium: .unavailable,
            unlisted: .notListed
        ])

        verify(coingecko).fetchPriceHistory(
            for: equal(to: taoPriceId),
            currency: equal(to: Currency.usd),
            period: equal(to: PriceHistoryPeriod.week)
        )

        verify(coingecko, times(1)).fetchPriceHistory(for: any(), currency: any(), period: any())
    }

    func testCoinsNotUpdatedWithinADayStayListedWithoutWeeklyPrices() throws {
        let coingecko = MockCoingeckoOperationFactoryProtocol()
        let celium = SubtensorSubnetRef(netuid: 51, registeredAt: 5_021_873)

        stubCharts(coingecko, [
            taoPriceId: [(0, "400"), (604_800, "440")],
            "chutes": [(0, "20"), (604_800, "33")]
        ])

        let service = makeService(coingecko: coingecko, markets: SubtensorSubnetMarkets(byNetuid: [
            chutes.netuid: market("chutes", change: 32, sparkline: [22, nil, 33], updatedAgo: 86401),
            templar.netuid: market("templar", change: -12, updatedAgo: 86400),
            celium.netuid: market("celium", change: 5, updatedAgo: nil)
        ]))

        let prices = try run(service.createWeeklyChangesWrapper(for: [chutes, templar, celium]))
        let chutesHistory = try run(service.createHistoryWrapper(for: chutes, period: .week, currency: .usd))

        XCTAssertEqual(prices, try [
            chutes: .unavailable,
            templar: .available(SubtensorWeeklyPriceSummary(change: decimal("-0.2"), sparkline: [])),
            celium: .unavailable
        ])

        XCTAssertNotEqual(chutesHistory, .notListed)
    }

    func testWeeklyPricesMarkEveryListedSubnetUnavailableWhenTheTaoChartFails() throws {
        let coingecko = MockCoingeckoOperationFactoryProtocol()

        stubCharts(coingecko, [
            "chutes": [(0, "20"), (604_800, "33")],
            "templar": [(0, "8.4"), (604_800, "8.8")]
        ])

        let prices = try run(makeService(coingecko: coingecko).createWeeklyChangesWrapper(
            for: [chutes, templar, unlisted]
        ))

        XCTAssertEqual(prices, [chutes: .unavailable, templar: .unavailable, unlisted: .notListed])
        verify(coingecko, never()).fetchPriceHistory(for: equal(to: "chutes"), currency: any(), period: any())
        verify(coingecko, never()).fetchPriceHistory(for: equal(to: "templar"), currency: any(), period: any())
    }

    func testPricesFailWhenTheMarketsRequestFails() {
        let coingecko = MockCoingeckoOperationFactoryProtocol()
        stubCharts(coingecko, [:])

        let service = makeService(coingecko: coingecko) {
            CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
        }

        XCTAssertThrowsError(try run(service.createWeeklyChangesWrapper(for: [chutes, unlisted])))
        XCTAssertThrowsError(try run(service.createHistoryWrapper(for: chutes, period: .week, currency: .usd)))
        verify(coingecko, never()).fetchPriceHistory(for: any(), currency: any(), period: any())
    }

    func testSparklineKeepsTheLastValueAndAtMostFortyEightValuesAtAnEvenStride() {
        let values = (0 ..< 170).map { Decimal($0) }

        let sparkline = SubtensorPriceHistoryService.sparkline(of: values)

        XCTAssertEqual(sparkline, stride(from: 1, through: 169, by: 4).map { Decimal($0) })
        XCTAssertEqual(sparkline.count, 43)
    }

    private func makeService(
        coingecko: MockCoingeckoOperationFactoryProtocol,
        markets: SubtensorSubnetMarkets? = nil
    ) -> SubtensorPriceHistoryService {
        let resolvedMarkets = markets ?? SubtensorSubnetMarkets(byNetuid: [
            chutes.netuid: market("chutes", change: 32, sparkline: [22, nil, 33]),
            templar.netuid: market("templar", change: -12)
        ])

        return makeService(coingecko: coingecko) {
            CompoundOperationWrapper.createWithResult(resolvedMarkets)
        }
    }

    private func makeService(
        coingecko: MockCoingeckoOperationFactoryProtocol,
        marketsWrapper: @escaping () -> CompoundOperationWrapper<SubtensorSubnetMarkets>
    ) -> SubtensorPriceHistoryService {
        let marketsService = MockSubtensorSubnetMarketsServiceProtocol()
        let blockNumberFactory = MockBlockNumberOperationFactoryProtocol()
        let now = now

        stub(marketsService) { stub in
            when(stub.createMarketsWrapper()).then {
                marketsWrapper()
            }
        }

        stub(blockNumberFactory) { stub in
            when(stub.createWrapper(for: any(), blockHash: any())).then { _, _ in
                CompoundOperationWrapper.createWithResult(BlockNumber.max)
            }
        }

        return SubtensorPriceHistoryService(
            marketsService: marketsService,
            coingeckoOperationFactory: coingecko,
            blockNumberOperationFactory: blockNumberFactory,
            chainId: KnowChainId.bittensor,
            taoPriceId: taoPriceId,
            operationQueue: OperationQueue(),
            timeProvider: { now }
        )
    }

    private func market(
        _ coingeckoId: String,
        change: Decimal?,
        sparkline: [Decimal?] = [],
        updatedAgo: TimeInterval? = 0
    ) -> SubtensorSubnetMarket {
        SubtensorSubnetMarket(
            coingeckoId: coingeckoId,
            weekChangePercent: change,
            weekSparkline: sparkline,
            lastUpdated: updatedAgo.map { Date(timeIntervalSince1970: now - $0) }
        )
    }

    private func stubCharts(_ coingecko: MockCoingeckoOperationFactoryProtocol, _ charts: [String: [(UInt64, String)]]) {
        stub(coingecko) { stub in
            when(stub.fetchPriceHistory(for: any(), currency: any(), period: any())).then { tokenId, _, _ in
                guard let chart = charts[tokenId] else {
                    return BaseOperation.createWithError(CommonError.dataCorruption)
                }

                return BaseOperation.createWithResult(self.history(chart))
            }
        }
    }

    private func history(_ chart: [(UInt64, String)]) -> PriceHistory {
        PriceHistory(
            currencyId: Currency.usd.id,
            items: chart.map { PriceHistoryItem(startedAt: $0.0, value: Decimal(string: $0.1) ?? 0) }
        )
    }

    private func decimal(_ text: String) throws -> Decimal {
        try XCTUnwrap(Decimal(string: text))
    }

    private func point(_ time: TimeInterval, taoPerAlpha: String, fiatPerAlpha: String) throws -> SubtensorPricePoint {
        try SubtensorPricePoint(
            date: Date(timeIntervalSince1970: time),
            taoPerAlpha: XCTUnwrap(Decimal(string: taoPerAlpha)),
            fiatPerAlpha: XCTUnwrap(Decimal(string: fiatPerAlpha))
        )
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        let completed = expectation(description: "wrapper completed")

        wrapper.targetOperation.completionBlock = {
            completed.fulfill()
        }

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)

        wait(for: [completed], timeout: 10)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
