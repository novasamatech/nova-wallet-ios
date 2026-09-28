import Cuckoo
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorYieldServiceTests: XCTestCase {
    private typealias YieldPage = BittensorApiResult<BittensorApi.AlphaYieldCollection>
    private typealias YieldRow = (netuid: UInt16, hotkey: String, rate: String)

    private let netuid: UInt16 = 64
    private let hotkeyA = Data(repeating: 0x0A, count: 32)
    private let hotkeyB = Data(repeating: 0x0B, count: 32)
    private let hotkeyC = Data(repeating: 0x0C, count: 32)
    private let olderAsOf = Date(timeIntervalSince1970: 1_790_000_000)
    private let newerAsOf = Date(timeIntervalSince1970: 1_790_000_600)

    func testAlphaYieldsKeepRawRatesPerHotkeyWithAggregatedStamp() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()

        try stubPages(apiFactory, [
            1: makePage(number: 1, nextPage: 2, asOf: newerAsOf, freshness: .stale, rows: [
                (netuid, address(of: hotkeyA), "12.5"),
                (netuid, "not-an-address", "3"),
                (12, address(of: hotkeyC), "8"),
                (netuid, address(of: hotkeyB), "0.034")
            ]),
            2: makePage(number: 2, nextPage: nil, asOf: olderAsOf, freshness: .fresh, rows: [
                (netuid, address(of: hotkeyA), "99"),
                (netuid, address(of: hotkeyC), "7")
            ])
        ])

        let yields = try run(makeService(apiFactory: apiFactory).createAlphaYieldsWrapper(for: netuid))

        let newerStale = SubtensorBackendStamp(asOf: newerAsOf, freshness: .stale)
        let olderFresh = SubtensorBackendStamp(asOf: olderAsOf, freshness: .fresh)

        let expected = SubtensorAlphaYields(
            netuid: netuid,
            yields: [
                hotkeyA: SubtensorReportedYield(reportedRate: "12.5", stamp: newerStale),
                hotkeyB: SubtensorReportedYield(reportedRate: "0.034", stamp: newerStale),
                hotkeyC: SubtensorReportedYield(reportedRate: "7", stamp: olderFresh)
            ],
            stamp: SubtensorBackendStamp(asOf: olderAsOf, freshness: .stale),
            isTruncated: false
        )

        XCTAssertEqual(yields, expected)
    }

    func testAlphaYieldsStopAtThreePagesAndFlagTruncation() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()

        try stubPages(apiFactory, [
            1: makePage(number: 1, nextPage: 2, asOf: olderAsOf, freshness: .fresh, rows: [
                (netuid, address(of: hotkeyA), "1")
            ]),
            2: makePage(number: 2, nextPage: 3, asOf: olderAsOf, freshness: .fresh, rows: [
                (netuid, address(of: hotkeyB), "2")
            ]),
            3: makePage(number: 3, nextPage: 4, asOf: olderAsOf, freshness: .fresh, rows: [
                (netuid, address(of: hotkeyC), "3")
            ])
        ])

        let yields = try run(makeService(apiFactory: apiFactory).createAlphaYieldsWrapper(for: netuid))

        XCTAssertTrue(yields.isTruncated)
        XCTAssertEqual(yields.yields.count, 3)
        verify(apiFactory, times(3)).createAlphaYieldWrapper(netuid: equal(to: netuid), page: any())
    }

    func testAlphaYieldsServedFromAnExpiredCacheAreStale() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()

        try stubPages(apiFactory, [
            1: makePage(number: 1, nextPage: nil, asOf: olderAsOf, freshness: .fresh, isFromExpiredCache: true, rows: [
                (netuid, address(of: hotkeyA), "12.5")
            ])
        ])

        let yields = try run(makeService(apiFactory: apiFactory).createAlphaYieldsWrapper(for: netuid))

        let expiredStamp = SubtensorBackendStamp(asOf: olderAsOf, freshness: .stale)

        XCTAssertEqual(yields.stamp, expiredStamp)
        XCTAssertEqual(yields.yields[hotkeyA], SubtensorReportedYield(reportedRate: "12.5", stamp: expiredStamp))
        XCTAssertNil(yields.yields[hotkeyA]?.annualRate)
    }

    func testAnnualRateReadsTheReportedRateAsPercentPoints() throws {
        let annualRate = reportedYield("12.5", freshness: .fresh).annualRate

        XCTAssertEqual(annualRate, try XCTUnwrap(Decimal(string: "0.125")))
    }

    func testAnnualRateIsNilWhenTheYieldIsStale() {
        XCTAssertNil(reportedYield("12.5", freshness: .stale).annualRate)
    }

    func testAnnualRateIsNilWhenTheReportedRateIsNegative() {
        XCTAssertNil(reportedYield("-3.2", freshness: .fresh).annualRate)
    }

    func testAnnualRateIsNilWhenANegativeRateRoundsToZeroAtDecimalPrecision() {
        let belowPrecision = "-0." + String(repeating: "0", count: 200) + "1"

        XCTAssertNil(reportedYield(belowPrecision, freshness: .fresh).annualRate)
    }

    func testAnnualRateIsNilWhenTheReportedRateIsUnparseable() {
        XCTAssertNil(reportedYield("12,5", freshness: .fresh).annualRate)
    }

    func testAnnualRateIsNilWhenTheReportedRateIsMissing() {
        XCTAssertNil(reportedYield("", freshness: .fresh).annualRate)
    }

    func testRootRateIsNetOfTheGivenTake() throws {
        let engine = MockSubtensorRewardCalculatorEngineProtocol()
        let netRate = try XCTUnwrap(Decimal(string: "0.0421"))

        stub(engine) { stub in
            when(stub.rootAnnualReturn(take: equal(to: UInt16(11796)))).thenReturn(netRate)
        }

        let take = Decimal(11796) / Decimal(SubtensorStakingPallet.perU16Denominator)
        let rate = try run(makeService(engineResult: .success(engine)).createRootNetworkRateWrapper(take: take))

        XCTAssertEqual(rate, SubtensorRate(annualRate: netRate, source: .chainNetworkAverage(isNetOfTake: true)))
        verify(engine).rootAnnualReturn(take: equal(to: UInt16(11796)))
    }

    func testRootRateIsGrossWithoutTake() throws {
        let engine = MockSubtensorRewardCalculatorEngineProtocol()
        let grossRate = try XCTUnwrap(Decimal(string: "0.0513"))

        stub(engine) { stub in
            when(stub.rootAnnualReturn()).thenReturn(grossRate)
        }

        let rate = try run(makeService(engineResult: .success(engine)).createRootNetworkRateWrapper(take: nil))

        XCTAssertEqual(rate, SubtensorRate(annualRate: grossRate, source: .chainNetworkAverage(isNetOfTake: false)))
    }

    func testRootRateIsNilWhenTheEngineIsUnavailable() throws {
        let service = makeService(engineResult: .failure(SubtensorRewardCalculatorError.rootSubnetMissing))

        let rate = try run(service.createRootNetworkRateWrapper(take: nil))

        XCTAssertNil(rate)
    }

    private func makeService(
        apiFactory: MockBittensorApiOperationFactoryProtocol = MockBittensorApiOperationFactoryProtocol(),
        engineResult: Result<SubtensorRewardCalculatorEngineProtocol, Error>? = nil
    ) -> SubtensorYieldService {
        let rewardCalculatorService = MockSubtensorRewardCalculatorServiceProtocol()

        if let engineResult {
            stub(rewardCalculatorService) { stub in
                when(stub.fetchEngine(runningCompletionIn: any(), completion: any())).then { queue, completion in
                    queue.async {
                        completion(engineResult)
                    }
                }
            }
        }

        return SubtensorYieldService(
            apiOperationFactory: apiFactory,
            rewardCalculatorService: rewardCalculatorService,
            operationQueue: OperationQueue()
        )
    }

    private func stubPages(_ apiFactory: MockBittensorApiOperationFactoryProtocol, _ pages: [Int: YieldPage]) {
        stub(apiFactory) { stub in
            when(stub.createAlphaYieldWrapper(netuid: any(), page: any())).then { _, page in
                guard let result = pages[page] else {
                    return CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
                }

                return CompoundOperationWrapper.createWithResult(result)
            }
        }
    }

    private func address(of accountId: AccountId) throws -> String {
        try accountId.toAddress(using: .substrate(SubstrateConstants.genericAddressPrefix))
    }

    private func reportedYield(
        _ reportedRate: String,
        freshness: SubtensorBackendStamp.Freshness
    ) -> SubtensorReportedYield {
        SubtensorReportedYield(
            reportedRate: reportedRate,
            stamp: SubtensorBackendStamp(asOf: newerAsOf, freshness: freshness)
        )
    }

    private func makePage(
        number: Int,
        nextPage: Int?,
        asOf: Date,
        freshness: BittensorApi.Freshness,
        isFromExpiredCache: Bool = false,
        rows: [YieldRow]
    ) -> YieldPage {
        let items = rows.map { row in
            BittensorApi.AlphaYield(
                metricKind: "ALPHA_VALIDATOR_APY",
                netuid: row.netuid,
                hotkey: row.hotkey,
                validatorName: "validator",
                reportedRate: row.rate,
                reportedValidatorTrust: "0.9",
                reportedAlphaDividendsPerHotkey: "1",
                reportedAlphaStake: "1000",
                reportedNominatedStake: "10",
                sourceTimestamp: "2026-09-24T00:00:00Z"
            )
        }

        let component = BittensorApi.AvailableComponent(
            asOf: asOf,
            freshness: freshness,
            valueQuality: .reported,
            sourceClass: .primary
        )

        let collection = BittensorApi.AlphaYieldCollection(
            items: items,
            meta: BittensorApi.AlphaYieldCollection.Meta(
                completeness: .complete,
                components: BittensorApi.AlphaYieldCollection.Components(alphaYield: component)
            ),
            pageInfo: BittensorApi.PageInfo(page: number, pageSize: 100, total: 300, nextPage: nextPage)
        )

        return BittensorApiResult(
            value: collection,
            requestId: "request-\(number)",
            receivedAt: 0,
            isFromExpiredCache: isFromExpiredCache
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
