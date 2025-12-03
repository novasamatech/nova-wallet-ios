import XCTest
@testable import novawallet
import Operation_iOS
import Cuckoo

class ChainRegistryTests: XCTestCase {
    func testSetupCompletionWhenAllChainsFullySynced() throws {
        // given

        let runtimeProviderPool = MockRuntimeProviderPoolProtocol()
        let connectionPool = MockConnectionPoolProtocol()
        let specVersionSubscriptionFactory = MockSpecVersionSubscriptionFactoryProtocol()
        let runtimeSyncService = MockRuntimeSyncServiceProtocol()

        stub(runtimeSyncService) { stub in
            stub.register(chain: any(), with: any()).thenDoNothing()
            stub.unregisterIfExists(chainId: any()).thenDoNothing()
        }

        let commonTypesSyncService = MockCommonTypesSyncServiceProtocol()

        stub(commonTypesSyncService) { stub in
            stub.syncUp().thenDoNothing()
        }

        let dataOperationFactory = MockDataOperationFactoryProtocol()

        let eventCenter = MockEventCenterProtocol()

        stub(eventCenter) { stub in
            stub.notify(with: any()).thenDoNothing()
        }

        let substrateChainsCount = 5
        let noRuntimeChainsCount = 5
        let remoteSubstrateChains = ChainModelGenerator.generateRemote(count: substrateChainsCount)
        let remoteNoRuntimeChains = ChainModelGenerator.generateRemote(count: noRuntimeChainsCount, hasSubstrateRuntime: false)
        let remoteChains = remoteSubstrateChains + remoteNoRuntimeChains

        let converter = ChainModelConverter()
        let expectedChains = remoteChains.enumerated().compactMap { index, remoteModel in
            converter.update(
                localModel: nil,
                remoteModel: remoteModel,
                additionals: .init(additionalAssets: [], order: Int64(index))
            )
        }

        let expectedChainIds = Set(expectedChains.map(\.chainId))
        let substrateChainIds = Set(remoteSubstrateChains.map(\.chainId))
        let chainsData = try JSONEncoder().encode(remoteChains)
        let evmTokensData = try JSONEncoder().encode([RemoteEvmToken]())
        let chainURL = URL(string: "https://github.com")!
        let evmAssetURL = URL(string: "https://google.com")!

        stub(dataOperationFactory) { stub in
            stub.fetchData(from: chainURL).thenReturn(BaseOperation.createWithResult(chainsData))
            stub.fetchData(from: evmAssetURL).thenReturn(BaseOperation.createWithResult(evmTokensData))
        }

        stub(runtimeProviderPool) { stub in
            let runtimeProvider = MockRuntimeProviderProtocol()
            stub.setupRuntimeProviderIfNeeded(for: any()).then { chain in
                if substrateChainIds.contains(chain.chainId) {
                    return runtimeProvider
                } else {
                    XCTFail("no runtime chains can't have runtime provider")
                    return runtimeProvider
                }
            }

            stub.getRuntimeProvider(for: any()).then { chainId in
                if substrateChainIds.contains(chainId) {
                    return runtimeProvider
                } else {
                    return nil
                }
            }

            stub.destroyRuntimeProviderIfExists(for: any()).thenDoNothing()
        }

        stub(connectionPool) { stub in
            let connection = MockConnection()
            stub.setupConnection(for: any()).thenReturn(connection)
            stub.getConnection(for: any()).thenReturn(connection)
        }

        let mockSubscription = MockSpecVersionSubscriptionProtocol()
        stub(mockSubscription) { stub in
            stub.subscribe().thenDoNothing()
            stub.unsubscribe().thenDoNothing()
        }

        stub(specVersionSubscriptionFactory) { stub in
            stub.createSubscription(for: any(), connection: any()).thenReturn(mockSubscription)
        }

        let storageFacade = SubstrateStorageTestFacade()

        let mapper = ChainModelMapper()
        let repository: CoreDataRepository<ChainModel, CDChain> = storageFacade.createRepository(
            mapper: AnyCoreDataMapper(mapper)
        )

        let chainSyncService = ChainSyncService(
            url: chainURL,
            evmAssetsURL: evmAssetURL,
            chainConverter: ChainModelConverter(),
            dataFetchFactory: dataOperationFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            operationQueue: OperationQueue()
        )

        let chainObserver = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: repository.dataMapper,
            predicate: { _ in true }
        )

        chainObserver.start { error in
            if let error = error {
                Logger.shared.error("Chain database observer unexpectedly failed: \(error)")
            }
        }

        let chainProvider = StreamableProvider(
            source: AnyStreamableSource(EmptyStreamableSource<ChainModel>()),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(chainObserver),
            operationManager: OperationManagerFacade.sharedManager
        )

        let registry = ChainRegistry(
            runtimeProviderPool: runtimeProviderPool,
            connectionPool: connectionPool,
            chainSyncService: chainSyncService,
            runtimeSyncService: runtimeSyncService,
            commonTypesSyncService: commonTypesSyncService,
            chainProvider: chainProvider,
            specVersionSubscriptionFactory: specVersionSubscriptionFactory,
            logger: Logger.shared
        )

        registry.syncUp()

        // when

        var setupChainIds = Set<ChainModel.Id>()

        let expectation = XCTestExpectation()

        registry.chainsSubscribe(self, runningInQueue: .main) { changes in
            guard !changes.isEmpty else {
                return
            }

            changes.forEach { change in
                if case let .insert(item) = change {
                    setupChainIds.insert(item.chainId)
                }
            }

            expectation.fulfill()
        }

        // then

        wait(for: [expectation], timeout: 10)

        XCTAssertEqual(expectedChainIds, setupChainIds)

        for chain in expectedChains {
            XCTAssertNotNil(registry.getConnection(for: chain.chainId))

            if substrateChainIds.contains(chain.chainId) {
                XCTAssertNotNil(registry.getRuntimeProvider(for: chain.chainId))
            } else {
                XCTAssertNil(registry.getRuntimeProvider(for: chain.chainId))
            }
        }

        verify(runtimeSyncService, times(substrateChainsCount)).register(chain: any(), with: any())
    }
}
