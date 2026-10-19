import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorAlphaPriceOperationFactoryTests: XCTestCase {
    private let asOf = Date(timeIntervalSince1970: 1_790_000_000)
    private let chutes: UInt16 = 64
    private let targon: UInt16 = 4

    func testFreshBackendPricesEveryHeldSubnetWithoutReadingTheChain() throws {
        let catalogueOperationFactory = createCatalogueOperationFactory(
            .success(catalogue([chutes: 50_000_000, targon: 40_000_000]))
        )
        let apiFactory = createApiFactory(chain: [chutes: 70_000_000, targon: 41_000_000])

        let prices = try run(
            createOperationFactory(catalogueOperationFactory, apiFactory).createPricesWrapper(for: [chutes, targon])
        )

        XCTAssertEqual(prices.taoPerAlpha, [chutes: 50_000_000, targon: 40_000_000])
        XCTAssertEqual(prices.catalogue?.subnets.map(\.netuid).sorted(), [targon, chutes])
        verify(apiFactory, never()).createAlphaPricesWrapper()
    }

    func testStalePricesComponentPricesEveryHeldSubnetFromTheChain() throws {
        let stale = catalogue([chutes: 50_000_000, targon: 40_000_000], freshness: .stale)
        let catalogueOperationFactory = createCatalogueOperationFactory(.success(stale))
        let apiFactory = createApiFactory(chain: [chutes: 70_000_000, targon: 41_000_000, 7: 1_000_000])

        let prices = try run(
            createOperationFactory(catalogueOperationFactory, apiFactory).createPricesWrapper(for: [chutes, targon])
        )

        XCTAssertEqual(prices, SubtensorAlphaPrices(catalogue: stale, taoPerAlpha: [chutes: 70_000_000, targon: 41_000_000]))
    }

    func testHeldSubnetMissingFromTheBackendIsFilledFromTheChain() throws {
        let catalogueOperationFactory = createCatalogueOperationFactory(.success(catalogue([chutes: 50_000_000])))
        let apiFactory = createApiFactory(chain: [chutes: 70_000_000, targon: 41_000_000])

        let prices = try run(
            createOperationFactory(catalogueOperationFactory, apiFactory).createPricesWrapper(for: [chutes, targon])
        )

        XCTAssertEqual(prices.taoPerAlpha, [chutes: 50_000_000, targon: 41_000_000])
    }

    func testBackendAndChainFailuresKeepOnlyTheExpiredCatalogueNames() throws {
        let expired = catalogue([chutes: 50_000_000], freshness: .stale)
        let catalogueOperationFactory = createCatalogueOperationFactory(
            .failure(BittensorApiError.unavailable(code: nil, requestId: nil)),
            cached: .expired(expired)
        )
        let apiFactory = createApiFactory(chain: nil)

        let prices = try run(
            createOperationFactory(catalogueOperationFactory, apiFactory).createPricesWrapper(for: [chutes])
        )

        XCTAssertEqual(prices, SubtensorAlphaPrices(catalogue: expired, taoPerAlpha: [:]))
    }

    private func catalogue(
        _ taoPerAlpha: [UInt16: Balance],
        freshness: SubtensorBackendStamp.Freshness = .fresh
    ) -> SubtensorSubnetCatalogue {
        let stamp = SubtensorBackendStamp(asOf: asOf, freshness: freshness)

        return SubtensorSubnetCatalogue(subnets: taoPerAlpha.map { netuid, price in
            SubtensorCatalogueSubnet(
                netuid: netuid,
                name: "Subnet \(netuid)",
                symbol: "α",
                networkRegisteredAt: 0,
                taoReserve: 0,
                alphaReserve: 0,
                alphaOutstanding: 0,
                taoPerAlpha: price,
                metadataStamp: stamp,
                pricesStamp: stamp
            )
        })
    }

    private func createCatalogueOperationFactory(
        _ result: Result<SubtensorSubnetCatalogue, Error>,
        cached: HTTPCachePeek<SubtensorSubnetCatalogue> = .miss
    ) -> MockSubtensorSubnetCatalogueOperationFactoryProtocol {
        let catalogueOperationFactory = MockSubtensorSubnetCatalogueOperationFactoryProtocol()

        stub(catalogueOperationFactory) { stub in
            when(stub.createCatalogueWrapper()).then {
                switch result {
                case let .success(catalogue):
                    return CompoundOperationWrapper.createWithResult(catalogue)
                case let .failure(error):
                    return CompoundOperationWrapper.createWithError(error)
                }
            }
            when(stub.cachedCatalogue()).thenReturn(cached)
        }

        return catalogueOperationFactory
    }

    private func createApiFactory(chain: [UInt16: Balance]?) -> MockSubtensorApiOperationFactoryProtocol {
        let apiFactory = MockSubtensorApiOperationFactoryProtocol()

        stub(apiFactory) { stub in
            when(stub.createAlphaPricesWrapper()).then {
                guard let chain else {
                    return CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
                }

                return CompoundOperationWrapper.createWithResult(
                    chain.map { SubtensorPallet.SubnetPrice(netuid: $0.key, price: $0.value) }
                )
            }
        }

        return apiFactory
    }

    private func createOperationFactory(
        _ catalogueOperationFactory: MockSubtensorSubnetCatalogueOperationFactoryProtocol,
        _ apiFactory: MockSubtensorApiOperationFactoryProtocol
    ) -> SubtensorAlphaPriceOperationFactory {
        SubtensorAlphaPriceOperationFactory(
            catalogueOperationFactory: catalogueOperationFactory,
            chainOperationFactory: apiFactory,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
