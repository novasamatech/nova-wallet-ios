import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorSubnetCatalogueServiceTests: XCTestCase {
    private typealias SubnetsResult = BittensorApiResult<BittensorApi.SubnetCollection>

    private let chutesRef = SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295)

    func testCatalogueMapsFixtureSubnetsWithAtomicAmounts() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        stubSubnets(apiFactory, result: .success(try fixtureSubnets()))

        let catalogue = try run(createService(apiFactory).createCatalogueWrapper())

        XCTAssertEqual(catalogue.subnets.map(\.netuid), [1, 3, 4, 8, 9, 19, 51, 56, 64, 120])
        XCTAssertEqual(catalogue.subnet(for: 64), SubtensorCatalogueSubnet(
            netuid: 64,
            name: "Chutes",
            symbol: "ش",
            networkRegisteredAt: 4_531_295,
            tempo: 360,
            ownerColdkey: "5HAQXW8HcVSKCp6Se52dEePjsiFtkWqjTK9huLi1Hfa9DmTC",
            ownerHotkey: "5GBCaF2ekuV49ipSHxtntwHBNr8Lj3c2XYJtd8eacVwREVek",
            links: SubtensorSubnetLinks(
                githubRepo: "",
                subnetContact: "",
                subnetUrl: "",
                subnetWebsite: "",
                discord: "",
                additional: ""
            ),
            taoReserve: 187_432_117_000_000,
            alphaReserve: 3_410_260_348_230_173,
            alphaOutstanding: 5_120_000_000_000_000,
            taoPerAlpha: 54_961_234,
            metadataStamp: SubtensorBackendStamp(asOf: try date("2026-09-24T09:25:00Z"), freshness: .fresh),
            pricesStamp: SubtensorBackendStamp(asOf: try date("2026-09-24T09:29:30Z"), freshness: .fresh)
        ))
    }

    func testLookupByRefRejectsReRegisteredNetuid() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        stubSubnets(apiFactory, result: .success(try fixtureSubnets()))

        let catalogue = try run(createService(apiFactory).createCatalogueWrapper())
        let reregistered = SubtensorSubnetRef(netuid: chutesRef.netuid, registeredAt: chutesRef.registeredAt + 1)

        XCTAssertEqual(catalogue.subnet(for: chutesRef)?.ref, chutesRef)
        XCTAssertNil(catalogue.subnet(for: reregistered))
    }

    func testUnpublishedCatalogueFailsWithTheRouteError() {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        stubSubnets(apiFactory, result: .failure(BittensorApiError.routeNotPublished))

        XCTAssertThrowsError(try run(createService(apiFactory).createCatalogueWrapper())) { error in
            guard case .routeNotPublished = error as? BittensorApiError else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    private func createService(
        _ apiFactory: MockBittensorApiOperationFactoryProtocol
    ) -> SubtensorSubnetCatalogueService {
        SubtensorSubnetCatalogueService(apiOperationFactory: apiFactory)
    }

    private func stubSubnets(
        _ apiFactory: MockBittensorApiOperationFactoryProtocol,
        result: Result<SubnetsResult, Error>
    ) {
        stub(apiFactory) { stub in
            when(stub.createSubnetsWrapper()).then {
                switch result {
                case let .success(response):
                    return CompoundOperationWrapper.createWithResult(response)
                case let .failure(error):
                    return CompoundOperationWrapper.createWithError(error)
                }
            }
        }
    }

    private func fixtureSubnets() throws -> SubnetsResult {
        let body = try JSONSerialization.data(withJSONObject: BittensorApiFixtureDocuments.subnets())
        let collection = try JSONDecoder().decode(BittensorApi.SubnetCollection.self, from: body)

        return BittensorApiResult(
            value: collection,
            requestId: "req-subnets",
            receivedAt: 0,
            isFromExpiredCache: false
        )
    }

    private func date(_ text: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: text))
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
