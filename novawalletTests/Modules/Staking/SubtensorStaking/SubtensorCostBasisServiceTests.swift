import Cuckoo
@testable import novawallet
import BigInt
import Operation_iOS
import XCTest

final class SubtensorCostBasisServiceTests: XCTestCase {
    private typealias OperationsPage = BittensorApiResult<BittensorApi.OperationCollection>

    private let accountId = Data(repeating: 7, count: 32)
    private let clock: TimeInterval = 1000
    private let chutesNetuid: UInt16 = 64

    func testAverageAcrossPagesSkipsOtherSubnetsAndMoves() throws {
        let apiOperationFactory = createApiOperationFactory(pages: [
            createPage(1, nextPage: 2, rows: [
                createOperation(netuid: chutesNetuid, amountIn: "1.25", amountOut: "-25", price: "0.05"),
                createOperation(netuid: chutesNetuid, amountIn: "10", amountOut: "0.512", price: "0.0512"),
                createOperation(netuid: 19, amountIn: "2", amountOut: "250", price: "0.008"),
                createOperation(netuid: chutesNetuid, amountIn: "5", amountOut: "5", price: "0.05", label: " Stake Move "),
                createOperation(netuid: chutesNetuid, amountIn: "2", amountOut: "40", price: "0.05", label: "StakeMoved")
            ]),
            createPage(2, nextPage: nil, rows: [
                createOperation(netuid: chutesNetuid, amountIn: "3.000000001", amountOut: "50", price: "0.06")
            ])
        ])
        let accountSubject = try accountId.toAddress(using: .defaultSubstrateFormat)
        let service = createService(apiOperationFactory)

        let costBasis = try run(service.createCostBasisWrapper(for: accountId, netuid: chutesNetuid))

        guard case let .average(totals) = costBasis else {
            return XCTFail("Unexpected cost basis: \(costBasis)")
        }
        XCTAssertEqual(totals, SubtensorPurchaseTotals(paidTao: 3_650_000_000, receivedAlpha: 65_000_000_000))
        XCTAssertEqual(totals.averagePrice.decimalValue, Decimal(string: "0.056153846153846153846153846153846153846"))
        verify(apiOperationFactory, times(1)).createOperationsWrapper(
            accountSubject: equal(to: accountSubject),
            page: equal(to: 2)
        )
    }

    func testUnclassifiedOperationFailsCostBasis() {
        let apiOperationFactory = createApiOperationFactory(pages: [
            createPage(1, nextPage: nil, rows: [
                createOperation(netuid: chutesNetuid, amountIn: "1.25", amountOut: "25", price: "0.05"),
                createOperation(netuid: chutesNetuid, amountIn: "2", amountOut: "3", price: "0.05")
            ])
        ])
        let wrapper = createService(apiOperationFactory).createCostBasisWrapper(for: accountId, netuid: chutesNetuid)

        XCTAssertThrowsError(try run(wrapper)) { error in
            XCTAssertEqual(error as? SubtensorCostBasisError, .unclassifiedOperations(netuid: self.chutesNetuid))
        }
    }

    func testTruncatedHistoryIsIncompleteNotNoPurchases() throws {
        let pages = (1 ... SubtensorCostBasisService.maxPages).map { page in
            createPage(page, nextPage: page + 1, rows: [])
        }
        let service = createService(createApiOperationFactory(pages: pages))

        let costBasis = try run(service.createCostBasisWrapper(for: accountId, netuid: chutesNetuid))

        XCTAssertEqual(costBasis, .incompleteHistory)
    }

    func testLabelBreaksTieWhenPriceFitsBothSides() throws {
        let apiOperationFactory = createApiOperationFactory(pages: [
            createPage(1, nextPage: nil, rows: [
                createOperation(netuid: chutesNetuid, amountIn: "4", amountOut: "4.6", price: "1.2", label: "remove_stake"),
                createOperation(netuid: chutesNetuid, amountIn: "10", amountOut: "8", price: "1.2", label: "StakeAdded")
            ])
        ])
        let service = createService(apiOperationFactory)

        let costBasis = try run(service.createCostBasisWrapper(for: accountId, netuid: chutesNetuid))

        XCTAssertEqual(
            costBasis,
            .average(SubtensorPurchaseTotals(paidTao: 5_000_000_000, receivedAlpha: 4_000_000_000))
        )
    }

    func testOwnStakingChangeDropsCostBasisSeed() throws {
        let apiOperationFactory = createApiOperationFactory(pages: [
            createPage(1, nextPage: nil, rows: [
                createOperation(netuid: chutesNetuid, amountIn: "1.25", amountOut: "25", price: "0.05")
            ])
        ])
        let eventQueue = DispatchQueue(label: "test.subtensor.cost.basis.events")
        let eventCenter = EventCenter(syncQueue: eventQueue)
        let accountSubject = try accountId.toAddress(using: .defaultSubstrateFormat)
        let service = createService(apiOperationFactory, eventCenter: eventCenter)

        let costBasis = try run(service.createCostBasisWrapper(for: accountId, netuid: chutesNetuid))
        XCTAssertEqual(service.cachedCostBasis(for: accountId, netuid: chutesNetuid).value, costBasis)

        eventCenter.notify(
            with: SubtensorStakeChanged(
                chainAssetId: ChainAssetId(chainId: KnowChainId.bittensor, assetId: AssetModel.utilityAssetId),
                accountId: accountId,
                netuids: [chutesNetuid]
            )
        )
        eventQueue.sync {}
        verify(apiOperationFactory, times(1)).dropOperations(accountSubject: equal(to: accountSubject))
        XCTAssertNil(service.cachedCostBasis(for: accountId, netuid: chutesNetuid).value)

        _ = try run(service.createCostBasisWrapper(for: accountId, netuid: chutesNetuid))

        XCTAssertNil(service.cachedCostBasis(for: accountId, netuid: chutesNetuid).value)
        verify(apiOperationFactory, times(2)).createOperationsWrapper(accountSubject: any(), page: any())
    }

    func testOwnStakingChangeDropsPagesAgainWhenTheBlockExpires() throws {
        var now = clock
        let apiOperationFactory = createApiOperationFactory(pages: [
            createPage(1, nextPage: nil, rows: [
                createOperation(netuid: chutesNetuid, amountIn: "1.25", amountOut: "25", price: "0.05")
            ])
        ])
        let eventQueue = DispatchQueue(label: "test.subtensor.cost.basis.events")
        let eventCenter = EventCenter(syncQueue: eventQueue)
        let accountSubject = try accountId.toAddress(using: .defaultSubstrateFormat)
        let service = createService(apiOperationFactory, eventCenter: eventCenter, timeProvider: { now })

        eventCenter.notify(
            with: SubtensorStakeChanged(
                chainAssetId: ChainAssetId(chainId: KnowChainId.bittensor, assetId: AssetModel.utilityAssetId),
                accountId: accountId,
                netuids: [chutesNetuid]
            )
        )
        eventQueue.sync {}
        now += SubtensorCostBasisService.ownTradeSettleTime - 1
        XCTAssertNil(service.cachedCostBasis(for: accountId, netuid: chutesNetuid).value)
        verify(apiOperationFactory, times(1)).dropOperations(accountSubject: equal(to: accountSubject))

        now += 1
        XCTAssertNil(service.cachedCostBasis(for: accountId, netuid: chutesNetuid).value)
        verify(apiOperationFactory, times(2)).dropOperations(accountSubject: equal(to: accountSubject))

        XCTAssertNotNil(service.cachedCostBasis(for: accountId, netuid: chutesNetuid).value)
        verify(apiOperationFactory, times(2)).dropOperations(accountSubject: equal(to: accountSubject))
    }

    func testBuyingMoreAtHigherPriceRaisesAverage() {
        let totals = SubtensorPurchaseTotals(paidTao: 1_250_000_000, receivedAlpha: 25_000_000_000)

        let updated = totals.adding(paidTao: 3_000_000_000, receivedAlpha: 50_000_000_000)

        XCTAssertEqual(updated, SubtensorPurchaseTotals(paidTao: 4_250_000_000, receivedAlpha: 75_000_000_000))
        XCTAssertEqual(totals.averageTrend(to: updated), .rising)
    }

    func testSellingReportsEarnedTaoAgainstAverage() {
        let state = SubtensorCostBasisState.resolved(
            .average(SubtensorPurchaseTotals(paidTao: 1_250_000_000, receivedAlpha: 25_000_000_000))
        )

        let earned = state.earnedTao(from: .quoted(alpha: 10_000_000_000, tao: 600_000_000))

        XCTAssertEqual(earned, BigInt(100_000_000))
    }

    private func createService(
        _ apiOperationFactory: BittensorApiOperationFactoryProtocol,
        eventCenter: EventCenterProtocol = EventCenter(),
        timeProvider: (() -> TimeInterval)? = nil
    ) -> SubtensorCostBasisService {
        let clock = clock

        return SubtensorCostBasisService(
            apiOperationFactory: apiOperationFactory,
            operationQueue: OperationQueue(),
            eventCenter: eventCenter,
            timeProvider: timeProvider ?? { clock }
        )
    }

    private func createApiOperationFactory(pages: [OperationsPage]) -> MockBittensorApiOperationFactoryProtocol {
        let apiOperationFactory = MockBittensorApiOperationFactoryProtocol()

        stub(apiOperationFactory) { stub in
            when(stub.createOperationsWrapper(accountSubject: any(), page: any())).then { _, page in
                guard let operationsPage = pages.first(where: { $0.value.pageInfo.page == page ?? 1 }) else {
                    return CompoundOperationWrapper.createWithError(BittensorApiError.unavailable(code: "dataset_unavailable", requestId: nil))
                }

                return CompoundOperationWrapper.createWithResult(operationsPage)
            }
            when(stub.peekOperations(accountSubject: any(), page: any())).then { _, page in
                pages.first { $0.value.pageInfo.page == page }.map { HTTPCachePeek.expired($0) } ?? .miss
            }
            when(stub.dropOperations(accountSubject: any())).thenDoNothing()
        }

        return apiOperationFactory
    }

    private func createPage(_ page: Int, nextPage: Int?, rows: [BittensorApi.Operation]) -> OperationsPage {
        let collection = BittensorApi.OperationCollection(
            items: rows,
            pageInfo: BittensorApi.PageInfo(page: page, pageSize: 100, total: 101, nextPage: nextPage),
            historyScope: "TAO_APP_PARTIAL",
            meta: BittensorApi.OperationCollection.Meta(
                completeness: .complete,
                components: BittensorApi.OperationCollection.Components(
                    operationHistory: BittensorApi.AvailableComponent(
                        asOf: Date(timeIntervalSince1970: 1_790_000_000),
                        freshness: .fresh
                    )
                )
            )
        )

        return OperationsPage(value: collection, requestId: nil, isFromExpiredCache: false)
    }

    private func createOperation(
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
            hotkey: "validator-hotkey",
            reportedAmountIn: amountIn,
            reportedAmountOut: amountOut,
            reportedPrice: price,
            sourceExtrinsicReference: "9140000-0001",
            sourceOperationType: label
        )
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
