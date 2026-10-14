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
                createOperation(netuid: chutesNetuid, amountIn: "5", amountOut: "5", price: "0.05", label: " Stake Move ")
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

    func testOwnStakingChangeRefetchesHistory() throws {
        let apiOperationFactory = createApiOperationFactory(pages: [
            createPage(1, nextPage: nil, rows: [
                createOperation(netuid: chutesNetuid, amountIn: "1.25", amountOut: "25", price: "0.05")
            ])
        ])
        let eventQueue = DispatchQueue(label: "test.subtensor.cost.basis.events")
        let eventCenter = EventCenter(syncQueue: eventQueue)
        let service = createService(apiOperationFactory, eventCenter: eventCenter)

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

    private func createApiOperationFactory(pages: [OperationsPage]) -> MockBittensorApiOperationFactoryProtocol {
        let apiOperationFactory = MockBittensorApiOperationFactoryProtocol()

        stub(apiOperationFactory) { stub in
            when(stub.createOperationsWrapper(accountSubject: any(), page: any())).then { _, page in
                guard let operationsPage = pages.first(where: { $0.value.pageInfo.page == page ?? 1 }) else {
                    return CompoundOperationWrapper.createWithError(BittensorApiError.datasetUnavailable(requestId: nil))
                }

                return CompoundOperationWrapper.createWithResult(operationsPage)
            }
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
                        freshness: .fresh,
                        valueQuality: .reported,
                        sourceClass: .primary
                    )
                )
            )
        )

        return OperationsPage(value: collection, requestId: nil, receivedAt: clock, isFromExpiredCache: false)
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
        let completed = expectation(description: "wrapper completed")
        wrapper.targetOperation.completionBlock = {
            completed.fulfill()
        }

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [completed], timeout: 10)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
