import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorPriceHistoryServiceTests: XCTestCase {
    private let taoPriceId = "bittensor"
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

    func testHistoryIsNotListedWithoutACoingeckoId() throws {
        let coingecko = MockCoingeckoOperationFactoryProtocol()
        stubCharts(coingecko, [:])

        let service = makeService(coingecko: coingecko, config: makeConfig(chutesId: nil))
        let result = try run(service.createHistoryWrapper(for: chutes, period: .week, currency: .usd))

        XCTAssertEqual(result, .notListed)
        verify(coingecko, never()).fetchPriceHistory(for: any(), currency: any(), period: any())
    }

    func testHistoryIsNotListedForAnotherRegistrationOfTheNetuid() throws {
        let coingecko = MockCoingeckoOperationFactoryProtocol()
        stubCharts(coingecko, [:])

        let reRegistered = SubtensorSubnetRef(netuid: chutes.netuid, registeredAt: 9_000_000)
        let result = try run(makeService(coingecko: coingecko).createHistoryWrapper(
            for: reRegistered,
            period: .week,
            currency: .usd
        ))

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

    func testWeeklyChangesAreTaoDenominatedForListedSubnetsWithAWeekOfHistory() throws {
        let coingecko = MockCoingeckoOperationFactoryProtocol()

        stubCharts(coingecko, [
            taoPriceId: [(0, "400"), (518_400, "420"), (604_800, "440")],
            "chutes": [(0, "20"), (604_800, "33")],
            "templar": [(518_400, "8.4"), (604_800, "8.8")]
        ])

        let changes = try run(makeService(coingecko: coingecko).createWeeklyChangesWrapper(
            for: [chutes, templar, unlisted]
        ))

        XCTAssertEqual(changes, try [chutes: XCTUnwrap(Decimal(string: "0.5"))])

        verify(coingecko, times(3)).fetchPriceHistory(
            for: any(),
            currency: equal(to: Currency.usd),
            period: equal(to: PriceHistoryPeriod.week)
        )
    }

    func testWeeklyChangesRunAtMostFourAlphaChartsAtOnce() throws {
        let coingecko = MockCoingeckoOperationFactoryProtocol()
        let tracker = InFlightTracker()
        let subnets = (100 ..< 110).map { SubtensorSubnetRef(netuid: UInt16($0), registeredAt: 1) }
        let taoHistory = history([(0, "400"), (604_800, "400")])
        let alphaHistory = history([(0, "20"), (604_800, "22")])

        stub(coingecko) { stub in
            when(stub.fetchPriceHistory(for: any(), currency: any(), period: any())).then { tokenId, _, _ in
                guard tokenId != self.taoPriceId else {
                    return BaseOperation.createWithResult(taoHistory)
                }

                return ClosureOperation<PriceHistory> {
                    tracker.enter()
                    usleep(50000)
                    tracker.leave()
                    return alphaHistory
                }
            }
        }

        let config = SubtensorEarnConfig(
            version: 1,
            entry: nil,
            headlineMaxAnnualRate: nil,
            preferredRootValidator: nil,
            logoBaseUrl: nil,
            subnets: Dictionary(uniqueKeysWithValues: subnets.map { subnet -> (UInt16, SubtensorEarnConfig.SubnetEntry) in
                let entry = SubtensorEarnConfig.SubnetEntry(
                    registeredAt: 1,
                    preferredValidator: nil,
                    coingeckoId: "sn\(subnet.netuid)",
                    logo: nil
                )

                return (subnet.netuid, entry)
            }),
            invalidEntries: []
        )

        let changes = try run(makeService(coingecko: coingecko, config: config).createWeeklyChangesWrapper(for: subnets))

        XCTAssertEqual(changes.count, subnets.count)
        XCTAssertLessThanOrEqual(tracker.maxInFlight, 4)
    }

    func testSubnetMarketsChangeIsTheAlphaChangeRelativeToTheTaoChange() throws {
        let markets = Data("""
        [
          {"id": "chutes", "symbol": "sn64", "current_price": 26.48, "price_change_percentage_7d_in_currency": 32},
          {"id": "templar", "symbol": "sn3", "current_price": 3.1, "price_change_percentage_7d_in_currency": -12},
          {"id": "celium", "symbol": "sn51", "current_price": 1.2, "price_change_percentage_7d_in_currency": null}
        ]
        """.utf8)

        let changes = try SubtensorPriceHistoryService.subnetMarketChanges(
            from: markets,
            taoWeekItems: history([(0, "400"), (604_800, "440")]).items,
            listed: [chutes: "chutes", templar: "templar", unlisted: "unknown-subnet"]
        )

        XCTAssertEqual(changes, try [
            chutes: XCTUnwrap(Decimal(string: "0.2")),
            templar: XCTUnwrap(Decimal(string: "-0.2"))
        ])
    }

    private final class InFlightTracker {
        private let lock = NSLock()
        private var current = 0
        private(set) var maxInFlight = 0

        func enter() {
            lock.lock()
            current += 1
            maxInFlight = max(maxInFlight, current)
            lock.unlock()
        }

        func leave() {
            lock.lock()
            current -= 1
            lock.unlock()
        }
    }

    private func makeService(
        coingecko: MockCoingeckoOperationFactoryProtocol,
        config: SubtensorEarnConfig? = nil
    ) -> SubtensorPriceHistoryService {
        let configProvider = MockSubtensorEarnConfigProviderProtocol()
        let resolvedConfig = config ?? makeConfig(chutesId: "chutes")

        stub(configProvider) { stub in
            when(stub.createConfigWrapper()).then {
                CompoundOperationWrapper.createWithResult(resolvedConfig)
            }
        }

        return SubtensorPriceHistoryService(
            earnConfigProvider: configProvider,
            coingeckoOperationFactory: coingecko,
            taoPriceId: taoPriceId,
            operationQueue: OperationQueue()
        )
    }

    private func makeConfig(chutesId: String?) -> SubtensorEarnConfig {
        SubtensorEarnConfig(
            version: 1,
            entry: nil,
            headlineMaxAnnualRate: nil,
            preferredRootValidator: nil,
            logoBaseUrl: nil,
            subnets: [
                chutes.netuid: .init(
                    registeredAt: chutes.registeredAt,
                    preferredValidator: nil,
                    coingeckoId: chutesId,
                    logo: nil
                ),
                templar.netuid: .init(
                    registeredAt: templar.registeredAt,
                    preferredValidator: nil,
                    coingeckoId: "templar",
                    logo: nil
                )
            ],
            invalidEntries: []
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
