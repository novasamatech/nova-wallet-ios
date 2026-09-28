import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorRankingViewServiceTests: XCTestCase {
    private typealias RankingsResult = BittensorApiResult<BittensorApi.SubnetRankingCollection>

    func testRankingViewCarriesTheFixtureRowsWithTheirGeneration() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        let fixture = try fixtureRankings()

        stub(apiFactory) { stub in
            when(stub.createRankedSubnetsWrapper()).then {
                CompoundOperationWrapper.createWithResult(fixture)
            }
        }

        let recommendationService = makeRecommendationService(apiFactory)

        let view = try XCTUnwrap(try run(makeService(recommendationService).createRankingViewWrapper()))
        let chutes = try XCTUnwrap(view.subnet(for: 64))

        let generationStamp = SubtensorBackendStamp(asOf: try date("2026-09-24T09:23:00Z"), freshness: .fresh)

        XCTAssertEqual(view.items.first?.netuid, SubtensorStakingPallet.rootNetuid)
        XCTAssertEqual(view.generation.id, BittensorApiFixtureWorld.generationId)
        XCTAssertEqual(view.generation.ageSeconds, 420)
        XCTAssertEqual(view.generation.stamp, generationStamp)
        XCTAssertEqual(chutes.status, .scored)
        XCTAssertEqual(chutes.riskClass, .balanced)
        XCTAssertEqual(chutes.ageBlocks, 4_608_585)
        XCTAssertEqual(chutes.scoredValidators, 16)
        XCTAssertEqual(chutes.eligibleValidators, 14)
        XCTAssertEqual(chutes.breakdown?.volatility.normalized, try XCTUnwrap(Decimal(string: "24.92")))
        XCTAssertEqual(recommendationService.lastSeenClientGates(), .backendDefault)
    }

    func testRankingViewIsAbsentWhenTheRouteIsNotPublished() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()

        stub(apiFactory) { stub in
            when(stub.createRankedSubnetsWrapper()).then {
                CompoundOperationWrapper.createWithError(BittensorApiError.routeNotPublished)
            }
        }

        let recommendationService = makeRecommendationService(apiFactory)

        let view = try run(makeService(recommendationService).createRankingViewWrapper())

        XCTAssertNil(view)
        XCTAssertNil(recommendationService.lastSeenClientGates())
    }

    func testRankingViewIsAbsentWhenTheRouteIsDown() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()

        let routeDown = BittensorApiError.datasetUnavailable(requestId: "req-ranking-down")

        stub(apiFactory) { stub in
            when(stub.createRankedSubnetsWrapper()).then {
                CompoundOperationWrapper.createWithError(routeDown)
            }
        }

        let view = try run(makeService(makeRecommendationService(apiFactory)).createRankingViewWrapper())

        XCTAssertNil(view)
    }

    private func makeService(
        _ recommendationService: SubtensorRecommendationServiceProtocol
    ) -> SubtensorRankingViewService {
        SubtensorRankingViewService(recommendationService: recommendationService)
    }

    private func makeRecommendationService(
        _ apiFactory: MockBittensorApiOperationFactoryProtocol
    ) -> SubtensorRecommendationService {
        SubtensorRecommendationService(
            apiOperationFactory: apiFactory,
            chainOperationFactory: MockSubtensorValidatorChainOperationFactoryProtocol(),
            operationQueue: OperationQueue()
        )
    }

    private func fixtureRankings() throws -> RankingsResult {
        let body = try JSONSerialization.data(withJSONObject: BittensorApiFixtureDocuments.rankedSubnets())
        let collection = try JSONDecoder().decode(BittensorApi.SubnetRankingCollection.self, from: body)

        return BittensorApiResult(value: collection, requestId: "req-ranking", receivedAt: 0, isFromExpiredCache: false)
    }

    private func date(_ text: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: text))
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
