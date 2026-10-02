import XCTest
@testable import novawallet
import NovaCrypto
import Operation_iOS

final class BittensorApiFixtureTransportTests: XCTestCase {
    func testSubnetsFixtureDecodesTenSubnetsIncludingNetuid64() throws {
        let collection = try fetch(
            BittensorApi.SubnetCollection.self,
            request: makeGetRequest(path: "/subnets", pathTemplate: "/subnets")
        )

        let chutes = try XCTUnwrap(collection.items.first { $0.netuid == 64 })

        XCTAssertEqual(collection.items.count, 10)
        XCTAssertEqual(collection.meta.completeness, .complete)
        XCTAssertEqual(chutes.networkRegisteredAt, 4_531_295)
        XCTAssertEqual(chutes.taoPerAlpha, "0.054961234")
    }

    func testValidatorsFixtureAnswersTheRequestedNetuidInHotkeyOrderWithPrefix42Keys() throws {
        let collection = try fetch(
            BittensorApi.ValidatorCollection.self,
            request: makeGetRequest(path: "/subnets/64/validators", pathTemplate: "/subnets/{netuid}/validators")
        )

        let hotkeys = collection.items.map(\.hotkey)
        let prefixes = try hotkeys.map { try SS58AddressFactory().type(fromAddress: $0).uint16Value }

        XCTAssertEqual(collection.items.count, 8)
        XCTAssertEqual(Set(collection.items.map(\.netuid)), [64])
        XCTAssertEqual(hotkeys, hotkeys.sorted())
        XCTAssertEqual(Set(prefixes), [42])
        XCTAssertEqual(collection.meta.completeness, .complete)
    }

    func testRootYieldFixtureDecodesOnePage() throws {
        let collection = try fetch(
            BittensorApi.RootYieldCollection.self,
            request: makeGetRequest(path: "/yields/root", pathTemplate: "/yields/root", query: ["page": "1"])
        )

        XCTAssertEqual(collection.items.map(\.metricKind), Array(repeating: "ROOT_AGGREGATE_APY", count: 3))
        XCTAssertEqual(collection.pageInfo, BittensorApi.PageInfo(page: 1, pageSize: 100, total: 3, nextPage: nil))
    }

    func testAlphaYieldFixturePagesTheRequestedNetuid() throws {
        let collection = try fetch(
            BittensorApi.AlphaYieldCollection.self,
            request: makeGetRequest(
                path: "/subnets/64/yields/alpha",
                pathTemplate: "/subnets/{netuid}/yields/alpha",
                query: ["page": "1", "pageSize": "3"]
            )
        )

        XCTAssertEqual(collection.items.count, 3)
        XCTAssertEqual(Set(collection.items.map(\.netuid)), [64])
        XCTAssertEqual(collection.pageInfo, BittensorApi.PageInfo(page: 1, pageSize: 3, total: 8, nextPage: 2))
    }

    func testRecommendationsFixtureDecodesThreeClassesWithTheFixedClientChecks() throws {
        let collection = try fetch(
            BittensorApi.RecommendationCollection.self,
            request: makeGetRequest(path: "/recommendations", pathTemplate: "/recommendations")
        )

        let pairs = collection.classes.stable + collection.classes.balanced + collection.classes.higherUpside

        XCTAssertEqual(collection.classes.stable.map(\.netuid), [0, 0, 0])
        XCTAssertEqual(collection.classes.balanced.count, 3)
        XCTAssertEqual(collection.classes.higherUpside.count, 3)
        XCTAssertEqual(collection.meta.clientGates.maxTake, "0.18")
        XCTAssertTrue(pairs.allSatisfy { $0.clientChecks == [.uid, .validatorPermit, .take, .lastUpdate] })
    }

    func testRankedSubnetsFixtureListsRootFirstWithTheSameGeneration() throws {
        let transport = BittensorApiFixtureTransport()

        let ranking = try fetch(
            BittensorApi.SubnetRankingCollection.self,
            request: makeGetRequest(path: "/recommendations/subnets", pathTemplate: "/recommendations/subnets"),
            transport: transport
        )

        let recommendations = try fetch(
            BittensorApi.RecommendationCollection.self,
            request: makeGetRequest(path: "/recommendations", pathTemplate: "/recommendations"),
            transport: transport
        )

        XCTAssertEqual(ranking.items.first?.netuid, 0)
        XCTAssertEqual(ranking.items.first?.riskClass, .stable)
        XCTAssertEqual(ranking.items.count, 11)
        XCTAssertEqual(ranking.meta.generation, recommendations.meta.generation)
    }

    func testUnknownPathFailsAsRouteNotPublished() {
        let wrapper = BittensorApiFixtureTransport().createResponseWrapper(
            for: makeGetRequest(path: "/subnets/64/stakes", pathTemplate: "/subnets/{netuid}/stakes")
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        XCTAssertThrowsError(try wrapper.targetOperation.extractNoCancellableResultData()) { error in
            guard case .routeNotPublished = error as? BittensorApiError else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    private func fetch<T: Decodable>(
        _ type: T.Type,
        request: BittensorApiRequest,
        transport: BittensorApiFixtureTransport = BittensorApiFixtureTransport()
    ) throws -> T {
        let wrapper = transport.createResponseWrapper(for: request)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        let response = try wrapper.targetOperation.extractNoCancellableResultData()

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertNotNil(response.requestId)
        XCTAssertNotEqual(response.cacheDirectives, .notStorable)

        return try JSONDecoder().decode(type, from: response.body)
    }

    private func makeGetRequest(
        path: String,
        pathTemplate: String,
        query: KeyValuePairs<String, String> = [:]
    ) -> BittensorApiRequest {
        BittensorApiRequest(
            method: .get,
            path: path,
            pathTemplate: pathTemplate,
            queryItems: query.map { URLQueryItem(name: $0.key, value: $0.value) },
            jsonBody: nil
        )
    }
}
