import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorSubnetCatalogueOperationFactoryTests: XCTestCase {
    private typealias SubnetsResult = BittensorApiResult<BittensorApi.SubnetCollection>

    private let chutesRef = SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295)

    private let subnetsJson = """
    {"items":[{"additional":"","alphaOutstanding":"3100000.5","alphaReserve":"1902447.777523233","discord":"",\
    "githubRepo":"","name":"Apex","netuid":1,"networkRegisteredAt":1497824,\
    "ownerColdkey":"5FR9hRN4qnAH1hAuA4Uz6fcbf8pbunGwJBw4od269GsTE9Wh",\
    "ownerHotkey":"5HDLqB5Fh2iC3B3D97PiSXEtgDprFhYvFYyo32WrnB4wHEK7","reportedRootProportion":"0.1832",\
    "subnetContact":"","subnetUrl":"","subnetWebsite":"","symbol":"α","taoPerAlpha":"0.011480210",\
    "taoReserve":"21840.5","tempo":99},{"additional":"","alphaOutstanding":"5120000",\
    "alphaReserve":"3410260.348230173","discord":"","githubRepo":"","name":"Chutes","netuid":64,\
    "networkRegisteredAt":4531295,"ownerColdkey":"5HAQXW8HcVSKCp6Se52dEePjsiFtkWqjTK9huLi1Hfa9DmTC",\
    "ownerHotkey":"5GBCaF2ekuV49ipSHxtntwHBNr8Lj3c2XYJtd8eacVwREVek","reportedRootProportion":"0.1311",\
    "subnetContact":"","subnetUrl":"","subnetWebsite":"","symbol":"ش","taoPerAlpha":"0.054961234",\
    "taoReserve":"187432.117","tempo":360}],"meta":{"completeness":"COMPLETE","components":{\
    "alphaPrices":{"asOf":"2026-09-24T09:29:30Z","availability":"AVAILABLE","freshness":"FRESH",\
    "sourceClass":"PRIMARY","valueQuality":"REPORTED"},\
    "subnetMetadata":{"asOf":"2026-09-24T09:25:00Z","availability":"AVAILABLE","freshness":"FRESH",\
    "sourceClass":"PRIMARY","valueQuality":"REPORTED"}}}}
    """

    func testCatalogueMapsFixtureSubnetsWithAtomicAmounts() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        stubSubnets(apiFactory, result: .success(try fixtureSubnets()))

        let catalogue = try run(createOperationFactory(apiFactory).createCatalogueWrapper())

        XCTAssertEqual(catalogue.subnets.map(\.netuid), [1, 64])
        XCTAssertEqual(catalogue.subnet(for: 64), SubtensorCatalogueSubnet(
            netuid: 64,
            name: "Chutes",
            symbol: "ش",
            networkRegisteredAt: 4_531_295,
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

        let catalogue = try run(createOperationFactory(apiFactory).createCatalogueWrapper())
        let reregistered = SubtensorSubnetRef(netuid: chutesRef.netuid, registeredAt: chutesRef.registeredAt + 1)

        XCTAssertEqual(catalogue.subnet(for: chutesRef)?.ref, chutesRef)
        XCTAssertNil(catalogue.subnet(for: reregistered))
    }

    func testUnpublishedCatalogueFailsWithTheRouteError() {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        stubSubnets(apiFactory, result: .failure(BittensorApiError.unavailable(code: nil, requestId: nil)))

        XCTAssertThrowsError(try run(createOperationFactory(apiFactory).createCatalogueWrapper())) { error in
            guard case .unavailable(code: nil, requestId: nil) = error as? BittensorApiError else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    private func createOperationFactory(
        _ apiFactory: MockBittensorApiOperationFactoryProtocol
    ) -> SubtensorSubnetCatalogueOperationFactory {
        SubtensorSubnetCatalogueOperationFactory(apiOperationFactory: apiFactory)
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
        let collection = try JSONDecoder().decode(BittensorApi.SubnetCollection.self, from: Data(subnetsJson.utf8))

        return BittensorApiResult(
            value: collection,
            requestId: "req-subnets",
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
