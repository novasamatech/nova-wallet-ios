import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorSubnetMarketsServiceTests: XCTestCase {
    private let chutesMarkets = """
    [{"id": "chutes", "symbol": "sn64", "last_updated": "2026-09-30T10:15:42.000Z"}]
    """

    func testMarketsKeySubnetCoinsByTheNetuidInTheirSymbolInAnyCase() throws {
        let coingecko = MockCoingeckoOperationFactoryProtocol()
        let service = makeService(coingecko)

        stubMarkets(coingecko, body: """
        [
            {
                "id": "chutes",
                "symbol": "sn64",
                "last_updated": "2026-09-30T10:15:42.000Z",
                "price_change_percentage_7d_in_currency": 32,
                "sparkline_in_7d": {"price": [22, null, 33]}
            },
            {
                "id": "omega-any-to-any",
                "symbol": "SN21",
                "last_updated": "2026-09-30T10:15:42Z",
                "price_change_percentage_7d_in_currency": null
            },
            {"id": "wrapped-chutes", "symbol": "sn64"},
            {"id": "acore-ai-token", "symbol": "acore"},
            {"id": "snake-coin", "symbol": "snake"},
            {"id": "sn-coin", "symbol": "sn"},
            {"id": "Unsafe Id", "symbol": "sn5"}
        ]
        """)

        let markets = try run(service.createMarketsWrapper())
        let updatedAt = Date(timeIntervalSince1970: 1_790_763_342)

        XCTAssertEqual(markets, SubtensorSubnetMarkets(byNetuid: [
            64: SubtensorSubnetMarket(
                coingeckoId: "chutes",
                weekChangePercent: 32,
                weekSparkline: [22, nil, 33],
                lastUpdated: updatedAt
            ),
            21: SubtensorSubnetMarket(
                coingeckoId: "omega-any-to-any",
                weekChangePercent: nil,
                weekSparkline: [],
                lastUpdated: updatedAt
            )
        ]))
    }

    func testMarketsWithoutAnySubnetCoinFailAndTheNextReadFetchesAgain() throws {
        let coingecko = MockCoingeckoOperationFactoryProtocol()
        let service = makeService(coingecko)

        stubMarkets(coingecko, body: """
        [{"id": "acore-ai-token", "symbol": "acore", "last_updated": "2026-09-30T10:15:42.000Z"}]
        """)

        XCTAssertThrowsError(try run(service.createMarketsWrapper())) { error in
            guard case CommonError.dataCorruption = error else {
                return XCTFail("Unexpected error \(error)")
            }
        }

        stubMarkets(coingecko, body: chutesMarkets)

        let markets = try run(service.createMarketsWrapper())

        XCTAssertEqual(markets.market(for: 64)?.coingeckoId, "chutes")
        verify(coingecko, times(2)).fetchMarkets(category: any(), currency: any())
    }

    func testConcurrentReadsShareOneFetchAndLaterReadsUseTheCache() throws {
        let coingecko = MockCoingeckoOperationFactoryProtocol()
        stubMarkets(coingecko, body: chutesMarkets)

        let fetchQueue = OperationQueue()
        fetchQueue.isSuspended = true

        let service = makeService(coingecko, operationQueue: fetchQueue)
        let concurrentReads = expectation(description: "concurrent reads")
        concurrentReads.expectedFulfillmentCount = 2

        var concurrentMarkets: [Result<SubtensorSubnetMarkets, Error>] = []

        for _ in 0 ..< 2 {
            service.fetch(runningCompletionIn: .main) { result in
                concurrentMarkets.append(result)
                concurrentReads.fulfill()
            }
        }

        fetchQueue.isSuspended = false
        wait(for: [concurrentReads], timeout: 10)

        let laterMarkets = try run(service.createMarketsWrapper())

        XCTAssertEqual(try concurrentMarkets.map { try $0.get() }, [laterMarkets, laterMarkets])
        verify(coingecko, times(1)).fetchMarkets(category: any(), currency: any())
    }

    private func makeService(
        _ coingecko: MockCoingeckoOperationFactoryProtocol,
        operationQueue: OperationQueue = OperationQueue()
    ) -> SubtensorSubnetMarketsService {
        SubtensorSubnetMarketsService(coingeckoOperationFactory: coingecko, operationQueue: operationQueue)
    }

    private func stubMarkets(_ coingecko: MockCoingeckoOperationFactoryProtocol, body: String) {
        stub(coingecko) { stub in
            when(stub.fetchMarkets(category: any(), currency: any())).then { _, _ in
                BaseOperation.createWithResult(Data(body.utf8))
            }
        }
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
