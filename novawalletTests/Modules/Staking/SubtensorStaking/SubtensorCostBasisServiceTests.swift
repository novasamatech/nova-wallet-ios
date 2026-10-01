import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorCostBasisServiceTests: XCTestCase {
    private typealias OperationsPage = BittensorApiResult<BittensorApi.OperationCollection>

    private let accountId = Data(repeating: 7, count: 32)
    private let clock: TimeInterval = 1000
    private let chutesNetuid: UInt16 = 64

    func testAverageCountsTheSubnetPurchasesOfEveryPageInWholeTokenAmounts() throws {
        let apiOperationFactory = MockBittensorApiOperationFactoryProtocol()

        stubPages(apiOperationFactory, pages: [
            makePage(1, nextPage: 2, rows: [
                makeOperation(netuid: chutesNetuid, amountIn: "1.25", amountOut: "-25", price: "0.05"),
                makeOperation(netuid: chutesNetuid, amountIn: "10", amountOut: "0.512", price: "0.0512"),
                makeOperation(netuid: 19, amountIn: "2", amountOut: "250", price: "0.008"),
                makeOperation(netuid: chutesNetuid, amountIn: "5", amountOut: "5", price: "0.05", label: " Stake Move ")
            ]),
            makePage(2, nextPage: nil, rows: [
                makeOperation(netuid: chutesNetuid, amountIn: "3.000000001", amountOut: "50", price: "0.06")
            ])
        ])

        let accountSubject = try accountId.toAddress(using: .defaultSubstrateFormat)
        let service = makeService(apiOperationFactory)

        let costBasis = try run(service.createCostBasisWrapper(for: accountId, netuid: chutesNetuid))

        guard case let .average(totals) = costBasis else {
            return XCTFail("Unexpected cost basis: \(costBasis)")
        }

        XCTAssertEqual(totals, SubtensorPurchaseTotals(paidTao: 4_250_000_001, receivedAlpha: 75_000_000_000))
        XCTAssertEqual(totals.averagePrice.decimalValue, Decimal(string: "0.05666666668"))
        verify(apiOperationFactory, times(1)).createOperationsWrapper(
            accountSubject: equal(to: accountSubject),
            page: equal(to: 2)
        )
    }

    func testFixtureHistoryAveragesTheChutesPurchasesAndHasNoLiumPurchases() throws {
        let apiOperationFactory = BittensorApiOperationFactory(
            transport: BittensorApiFixtureTransport(),
            cache: BittensorApiResponseCache(operationQueue: OperationQueue(), logger: Logger.shared),
            logger: Logger.shared
        )

        let service = makeService(apiOperationFactory)

        let chutes = try run(service.createCostBasisWrapper(for: accountId, netuid: chutesNetuid))
        let lium = try run(service.createCostBasisWrapper(for: accountId, netuid: 51))

        XCTAssertEqual(
            chutes,
            .average(SubtensorPurchaseTotals(paidTao: 95_697_000_000, receivedAlpha: 1_869_010_901_513))
        )
        XCTAssertEqual(lium, .noPurchases)
    }

    func testOnlyAWholeMoveOrTransferWordInTheLabelSkipsAnOperation() throws {
        let apiOperationFactory = MockBittensorApiOperationFactoryProtocol()

        stubPages(apiOperationFactory, pages: [
            makePage(1, nextPage: nil, rows: [
                makeOperation(
                    netuid: chutesNetuid,
                    amountIn: "1.25",
                    amountOut: "25",
                    price: "0.05",
                    label: "RemoveStake"
                ),
                makeOperation(netuid: chutesNetuid, amountIn: "5", amountOut: "5", price: "0.05", label: "MoveStake"),
                makeOperation(
                    netuid: chutesNetuid,
                    amountIn: "4",
                    amountOut: "4",
                    price: "0.05",
                    label: "transfer_stake"
                )
            ])
        ])

        let service = makeService(apiOperationFactory)

        XCTAssertEqual(
            try run(service.createCostBasisWrapper(for: accountId, netuid: chutesNetuid)),
            .average(SubtensorPurchaseTotals(paidTao: 1_250_000_000, receivedAlpha: 25_000_000_000))
        )
    }

    func testOperationFittingNeitherTradeDirectionLeavesTheSubnetWithoutAnAverage() {
        let apiOperationFactory = MockBittensorApiOperationFactoryProtocol()

        stubPages(apiOperationFactory, pages: [
            makePage(1, nextPage: nil, rows: [
                makeOperation(netuid: chutesNetuid, amountIn: "1.25", amountOut: "25", price: "0.05"),
                makeOperation(netuid: chutesNetuid, amountIn: "2", amountOut: "3", price: "0.05")
            ])
        ])

        let wrapper = makeService(apiOperationFactory).createCostBasisWrapper(for: accountId, netuid: chutesNetuid)

        XCTAssertThrowsError(try run(wrapper)) { error in
            XCTAssertEqual(error as? SubtensorCostBasisError, .unclassifiedOperations(netuid: self.chutesNetuid))
        }
    }

    func testFailedHistoryIsNotMemoised() throws {
        let apiOperationFactory = MockBittensorApiOperationFactoryProtocol()

        let page = makePage(1, nextPage: nil, rows: [
            makeOperation(netuid: chutesNetuid, amountIn: "1.25", amountOut: "25", price: "0.05")
        ])

        stub(apiOperationFactory) { stub in
            when(stub.createOperationsWrapper(accountSubject: any(), page: any()))
                .then { _, _ in
                    CompoundOperationWrapper.createWithError(BittensorApiError.datasetUnavailable(requestId: nil))
                }
                .then { _, _ in
                    CompoundOperationWrapper.createWithResult(page)
                }
        }

        let service = makeService(apiOperationFactory)

        XCTAssertThrowsError(try run(service.createCostBasisWrapper(for: accountId, netuid: chutesNetuid)))

        XCTAssertEqual(
            try run(service.createCostBasisWrapper(for: accountId, netuid: chutesNetuid)),
            .average(SubtensorPurchaseTotals(paidTao: 1_250_000_000, receivedAlpha: 25_000_000_000))
        )
        verify(apiOperationFactory, times(2)).createOperationsWrapper(accountSubject: any(), page: equal(to: 1))
    }

    func testOwnTradeOnTheAccountDropsTheMemoisedHistory() throws {
        let apiOperationFactory = MockBittensorApiOperationFactoryProtocol()
        let eventQueue = DispatchQueue(label: "test.subtensor.cost.basis.events")
        let eventCenter = EventCenter(syncQueue: eventQueue)

        stubPages(apiOperationFactory, pages: [
            makePage(1, nextPage: nil, rows: [
                makeOperation(netuid: chutesNetuid, amountIn: "1.25", amountOut: "25", price: "0.05")
            ])
        ])

        let service = makeService(apiOperationFactory, eventCenter: eventCenter)

        _ = try run(service.createCostBasisWrapper(for: accountId, netuid: chutesNetuid))
        _ = try run(service.createCostBasisWrapper(for: accountId, netuid: chutesNetuid))

        verify(apiOperationFactory, times(1)).createOperationsWrapper(accountSubject: any(), page: any())

        eventCenter.notify(
            with: SubtensorStakingChanged(
                chainAssetId: ChainAssetId(chainId: KnowChainId.bittensor, assetId: AssetModel.utilityAssetId),
                accountId: accountId
            )
        )

        eventQueue.sync {}

        _ = try run(service.createCostBasisWrapper(for: accountId, netuid: chutesNetuid))

        verify(apiOperationFactory, times(2)).createOperationsWrapper(accountSubject: any(), page: any())
    }

    private func makeService(
        _ apiOperationFactory: BittensorApiOperationFactoryProtocol,
        eventCenter: EventCenterProtocol = EventCenter()
    ) -> SubtensorCostBasisService {
        let clock = clock

        return SubtensorCostBasisService(
            apiOperationFactory: apiOperationFactory,
            operationQueue: OperationQueue(),
            eventCenter: eventCenter,
            walkSettings: SubtensorCostBasisWalk.Settings(requestSpacing: 0, retryDelay: 0, maxPages: 10),
            timeProvider: { clock }
        )
    }

    private func stubPages(_ apiOperationFactory: MockBittensorApiOperationFactoryProtocol, pages: [OperationsPage]) {
        stub(apiOperationFactory) { stub in
            when(stub.createOperationsWrapper(accountSubject: any(), page: any())).then { _, page in
                guard let operationsPage = pages.first(where: { $0.value.pageInfo.page == page ?? 1 }) else {
                    return CompoundOperationWrapper.createWithError(BittensorApiError.datasetUnavailable(requestId: nil))
                }

                return CompoundOperationWrapper.createWithResult(operationsPage)
            }
        }
    }

    private func makePage(_ page: Int, nextPage: Int?, rows: [BittensorApi.Operation]) -> OperationsPage {
        let collection = BittensorApi.OperationCollection(
            items: rows,
            pageInfo: BittensorApi.PageInfo(page: page, pageSize: 100, total: 101, nextPage: nextPage),
            historyScope: "TAO_APP_PARTIAL",
            meta: BittensorApi.OperationCollection.Meta(
                completeness: .complete,
                components: BittensorApi.OperationCollection.Components(
                    operationHistory: BittensorApi.AvailableComponent(
                        asOf: Date(timeIntervalSince1970: 1_790_000_000),
                        freshness: .fresh,
                        valueQuality: .reported,
                        sourceClass: .primary
                    )
                )
            )
        )

        return OperationsPage(value: collection, requestId: nil, receivedAt: clock, isFromExpiredCache: false)
    }

    private func makeOperation(
        netuid: UInt16,
        amountIn: String,
        amountOut: String,
        price: String,
        label: String? = "trade"
    ) -> BittensorApi.Operation {
        BittensorApi.Operation(
            sourceEventId: "event-\(netuid)-\(amountIn)-\(amountOut)",
            sourceTimestamp: "2026-09-24T09:00:00Z",
            netuid: netuid,
            hotkey: BittensorApiFixtureWorld.validator(.cinder).hotkey,
            reportedAmountIn: amountIn,
            reportedAmountOut: amountOut,
            reportedPrice: price,
            sourceExtrinsicReference: "9140000-0001",
            sourceOperationType: label
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
