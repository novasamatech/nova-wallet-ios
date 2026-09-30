import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorSubnetMarketsStubFallbackTests: XCTestCase {
    private let capturedAt: TimeInterval = 1_790_776_160
    private let internetOfIntelligenceUpdatedAt: TimeInterval = 1_790_043_760
    private let captureAge = TimeInterval(30).secondsFromDays

    func testFailedMarketsRequestFallsBackToTheBundledStubMovedToTheFallbackTime() throws {
        let service = makeService { .createWithError(NetworkResponseError.resourceNotFound) }

        let markets = try run(makeFallback(service).createMarketsWrapper())

        XCTAssertEqual(markets.byNetuid.count, 116)
        XCTAssertEqual(markets.market(for: 64)?.coingeckoId, "chutes")
        XCTAssertEqual(markets.market(for: 64)?.lastUpdated, Date(timeIntervalSince1970: capturedAt + captureAge))
        XCTAssertEqual(markets.market(for: 108)?.coingeckoId, "internet-of-intelligence")
        XCTAssertEqual(
            markets.market(for: 108)?.lastUpdated,
            Date(timeIntervalSince1970: internetOfIntelligenceUpdatedAt + captureAge)
        )
    }

    func testLiveMarketsPassThroughTheStubFallback() throws {
        let liveMarkets = SubtensorSubnetMarkets(byNetuid: [
            64: SubtensorSubnetMarket(
                coingeckoId: "chutes",
                weekChangePercent: 32,
                weekSparkline: [22, nil, 33],
                lastUpdated: Date(timeIntervalSince1970: capturedAt)
            )
        ])

        let service = makeService { .createWithResult(liveMarkets) }

        let markets = try run(makeFallback(service).createMarketsWrapper())

        XCTAssertEqual(markets, liveMarkets)
    }

    func testDebugProcessServicesWrapTheMarketsServiceInTheStubFallback() throws {
        let fallback = try XCTUnwrap(
            SubtensorStakingProcessServices.shared.subnetMarketsService as? SubtensorSubnetMarketsStubFallback
        )

        XCTAssertTrue(fallback.service is SubtensorSubnetMarketsService)
    }

    private func makeService(
        marketsWrapper: @escaping () -> CompoundOperationWrapper<SubtensorSubnetMarkets>
    ) -> MockSubtensorSubnetMarketsServiceProtocol {
        let service = MockSubtensorSubnetMarketsServiceProtocol()

        stub(service) { stub in
            when(stub.createMarketsWrapper()).then {
                marketsWrapper()
            }
        }

        return service
    }

    private func makeFallback(
        _ service: MockSubtensorSubnetMarketsServiceProtocol
    ) -> SubtensorSubnetMarketsStubFallback {
        let fallbackTime = capturedAt + captureAge

        return SubtensorSubnetMarketsStubFallback(service: service, timeProvider: { fallbackTime })
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
