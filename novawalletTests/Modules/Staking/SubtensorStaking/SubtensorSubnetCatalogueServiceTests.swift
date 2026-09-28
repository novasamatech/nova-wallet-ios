import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorSubnetCatalogueServiceTests: XCTestCase {
    private typealias SubnetsResult = BittensorApiResult<BittensorApi.SubnetCollection>

    private let chutesRef = SubtensorSubnetRef(netuid: 64, registeredAt: 4_531_295)

    func testCatalogueMapsTheFixtureSubnetsWithAtomicAmountsAndComponentStamps() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        stubSubnets(apiFactory, results: [.success(try fixtureSubnets(isFromExpiredCache: false))])

        let catalogue = try run(makeService(apiFactory).createCatalogueWrapper(forcingRefresh: false))

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

    func testLookupByRefRequiresTheSameRegistrationOfTheNetuid() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        stubSubnets(apiFactory, results: [.success(try fixtureSubnets(isFromExpiredCache: false))])

        let catalogue = try run(makeService(apiFactory).createCatalogueWrapper(forcingRefresh: false))
        let reregistered = SubtensorSubnetRef(netuid: chutesRef.netuid, registeredAt: chutesRef.registeredAt + 1)

        XCTAssertEqual(catalogue.subnet(for: chutesRef)?.ref, chutesRef)
        XCTAssertNil(catalogue.subnet(for: reregistered))
    }

    func testCatalogueServedFromAnExpiredCacheIsStale() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        stubSubnets(apiFactory, results: [.success(try fixtureSubnets(isFromExpiredCache: true))])

        let catalogue = try run(makeService(apiFactory).createCatalogueWrapper(forcingRefresh: false))
        let chutes = try XCTUnwrap(catalogue.subnet(for: chutesRef))

        let staleMetadata = SubtensorBackendStamp(asOf: try date("2026-09-24T09:25:00Z"), freshness: .stale)
        let stalePrices = SubtensorBackendStamp(asOf: try date("2026-09-24T09:29:30Z"), freshness: .stale)

        XCTAssertEqual(chutes.metadataStamp, staleMetadata)
        XCTAssertEqual(chutes.pricesStamp, stalePrices)
    }

    func testUnpublishedCatalogueFailsWithTheRouteError() {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        stubSubnets(apiFactory, results: [.failure(BittensorApiError.routeNotPublished)])

        XCTAssertThrowsError(try run(makeService(apiFactory).createCatalogueWrapper(forcingRefresh: false))) { error in
            guard case .routeNotPublished = error as? BittensorApiError else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    func testReadAfterTheRouteWasDownAsksTheBackendAgain() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()

        stubSubnets(apiFactory, results: [
            .failure(BittensorApiError.datasetUnavailable(requestId: "req-subnets-down")),
            .success(try fixtureSubnets(isFromExpiredCache: false))
        ])

        let service = makeService(apiFactory)

        let downError = runError(service.createCatalogueWrapper(forcingRefresh: false))
        let catalogue = try run(service.createCatalogueWrapper(forcingRefresh: false))

        guard case let .datasetUnavailable(requestId)? = downError as? BittensorApiError else {
            return XCTFail("Unexpected error \(String(describing: downError))")
        }

        XCTAssertEqual(requestId, "req-subnets-down")
        XCTAssertEqual(catalogue.subnets.count, 10)
        verify(apiFactory, times(2)).createSubnetsWrapper()
    }

    func testSessionCacheServesOneBackendReadUntilARefreshIsForced() throws {
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        let fixture = try fixtureSubnets(isFromExpiredCache: false)
        stubSubnets(apiFactory, results: [.success(fixture), .success(fixture)])

        let service = makeService(apiFactory)

        let first = try run(service.createCatalogueWrapper(forcingRefresh: false))
        let cached = try run(service.createCatalogueWrapper(forcingRefresh: false))

        verify(apiFactory, times(1)).createSubnetsWrapper()

        let refreshed = try run(service.createCatalogueWrapper(forcingRefresh: true))

        XCTAssertEqual(cached, first)
        XCTAssertEqual(refreshed, first)
        verify(apiFactory, times(2)).createSubnetsWrapper()
    }

    private func makeService(
        _ apiFactory: MockBittensorApiOperationFactoryProtocol
    ) -> SubtensorSubnetCatalogueService {
        SubtensorSubnetCatalogueService(apiOperationFactory: apiFactory, operationQueue: OperationQueue())
    }

    private func stubSubnets(
        _ apiFactory: MockBittensorApiOperationFactoryProtocol,
        results: [Result<SubnetsResult, Error>]
    ) {
        let lock = NSLock()
        var remaining = results

        stub(apiFactory) { stub in
            when(stub.createSubnetsWrapper()).then {
                lock.lock()
                let next = remaining.isEmpty ? nil : remaining.removeFirst()
                lock.unlock()

                switch next {
                case let .success(result):
                    return CompoundOperationWrapper.createWithResult(result)
                case let .failure(error):
                    return CompoundOperationWrapper.createWithError(error)
                case nil:
                    return CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
                }
            }
        }
    }

    private func fixtureSubnets(isFromExpiredCache: Bool) throws -> SubnetsResult {
        let body = try JSONSerialization.data(withJSONObject: BittensorApiFixtureDocuments.subnets())
        let collection = try JSONDecoder().decode(BittensorApi.SubnetCollection.self, from: body)

        return BittensorApiResult(
            value: collection,
            requestId: "req-subnets",
            receivedAt: 0,
            isFromExpiredCache: isFromExpiredCache
        )
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

    private func runError<T>(_ wrapper: CompoundOperationWrapper<T>) -> Error? {
        do {
            _ = try run(wrapper)

            return nil
        } catch {
            return error
        }
    }
}
