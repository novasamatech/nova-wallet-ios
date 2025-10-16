import XCTest
@testable import novawallet
import Operation_iOS
import Cuckoo

class ChainSyncServiceTests: XCTestCase {
    let chainURL = URL(string: "https://github.com")!
    let evmAssetURL = URL(string: "https://google.com")!

    func testFetchedChainListApplied() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()

        let mapper = ChainModelMapper()
        let repository: CoreDataRepository<ChainModel, CDChain> =
            storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let operationQueue = OperationQueue()
        let eventCenter = MockEventCenterProtocol()
        let converter = ChainModelConverter()

        let chainService = ChainSyncService(
            url: chainURL,
            evmAssetsURL: evmAssetURL,
            chainConverter: ChainModelConverter(),
            dataFetchFactory: dataOperationFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            operationQueue: operationQueue
        )

        // when

        let remoteItems = ChainModelGenerator.generateRemote(count: 16)
        let localMappedItems = remoteItems.enumerated().compactMap { index, item in
            converter.update(localModel: nil, remoteModel: item, additionalAssets: [], order: Int64(index))
        }

        let newItems = Array(localMappedItems[0 ..< 8])
        let updatedItems = Array(localMappedItems[8 ..< 13])
        let deletedItems = Array(localMappedItems[13 ..< 16])
        let allItems = updatedItems + deletedItems + newItems
        let chainsData = try JSONEncoder().encode(remoteItems)
        let evmTokensData = try JSONEncoder().encode([RemoteEvmToken]())

        stub(dataOperationFactory) { stub in
            stub.fetchData(from: chainURL).thenReturn(BaseOperation.createWithResult(chainsData))
            stub.fetchData(from: evmAssetURL).thenReturn(BaseOperation.createWithResult(evmTokensData))
        }

        let repositoryPresetOperation = repository.saveOperation({
            updatedItems
        }, {
            deletedItems.map(\.identifier)
        })

        operationQueue.addOperations([repositoryPresetOperation], waitUntilFinished: true)

        let startExpectation = XCTestExpectation()
        let completionExpectation = XCTestExpectation()

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if event is ChainSyncDidStart {
                    startExpectation.fulfill()
                }

                if event is ChainSyncDidComplete {
                    completionExpectation.fulfill()
                }
            }
        }

        chainService.syncUp()

        // then

        wait(for: [startExpectation, completionExpectation], timeout: 10, enforceOrder: true)

        let localItemsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([localItemsOperation], waitUntilFinished: true)

        let localItems = try localItemsOperation.extractNoCancellableResultData()

        XCTAssertEqual(chainService.isSyncing, false)
        XCTAssertEqual(Set(localItems), Set(allItems))
    }

    func testSyncIsRetriedAfterFailure() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()

        let mapper = ChainModelMapper()
        let repository: CoreDataRepository<ChainModel, CDChain> =
            storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let operationQueue = OperationQueue()
        let eventCenter = MockEventCenterProtocol()

        let chainService = ChainSyncService(
            url: chainURL,
            evmAssetsURL: evmAssetURL,
            chainConverter: ChainModelConverter(),
            dataFetchFactory: dataOperationFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            operationQueue: operationQueue
        )

        // when

        let newItems = ChainModelGenerator.generateRemote(count: 8)
        let responseData = try JSONEncoder().encode(newItems)
        let failureOperation = BaseOperation<Data>.createWithError(
            BaseOperationError.unexpectedDependentResult
        )
        let successOperation = BaseOperation.createWithResult(responseData)
        let evmResponseData = try JSONEncoder().encode([RemoteEvmToken]())
        let evmSuccessOperation = BaseOperation.createWithResult(evmResponseData)
        let otherEvmSuccessOperation = BaseOperation.createWithResult(evmResponseData)

        stub(dataOperationFactory) { stub in
            stub.fetchData(from: chainURL).thenReturn(failureOperation, successOperation)
            stub.fetchData(from: evmAssetURL).thenReturn(evmSuccessOperation, otherEvmSuccessOperation)
        }

        let failureExpectation = XCTestExpectation()
        let completionExpectation = XCTestExpectation()

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if event is ChainSyncDidFail {
                    failureExpectation.fulfill()
                }

                if event is ChainSyncDidComplete {
                    completionExpectation.fulfill()
                }
            }
        }

        chainService.syncUp()

        // then

        wait(for: [failureExpectation, completionExpectation], timeout: 10, enforceOrder: true)

        XCTAssertEqual(chainService.isSyncing, false)
        XCTAssertEqual(chainService.retryAttempt, 0)
    }

    func testEvmTokensAreSynced() throws {
        let storageFacade = SubstrateStorageTestFacade()
        let mapper = ChainModelMapper()
        let repository: CoreDataRepository<ChainModel, CDChain> =
            storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let operationQueue = OperationQueue()
        let eventCenter = MockEventCenterProtocol()

        let converter = ChainModelConverter()
        let chainService = ChainSyncService(
            url: chainURL,
            evmAssetsURL: evmAssetURL,
            chainConverter: converter,
            dataFetchFactory: dataOperationFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            operationQueue: operationQueue
        )

        // when

        let remoteItems = ChainModelGenerator.generateRemote(count: 3)
        let chainWithEvmTokens = remoteItems[0]
        let otherChainWithEvmTokens = remoteItems[1]
        let evmToken = ChainModelGenerator.generateEvmToken(
            chainId1: chainWithEvmTokens.chainId,
            chainId2: otherChainWithEvmTokens.chainId
        )
        let usdChainAssets = [evmToken].chainAssets()

        let chainsData = try JSONEncoder().encode(remoteItems)
        let evmTokensData = try JSONEncoder().encode([evmToken])

        let expectedResult = remoteItems.enumerated().compactMap { index, remoteItem in
            converter.update(
                localModel: nil,
                remoteModel: remoteItem,
                additionalAssets: usdChainAssets[remoteItem.chainId] ?? [],
                order: Int64(index)
            )
        }

        stub(dataOperationFactory) { stub in
            stub.fetchData(from: chainURL).thenReturn(BaseOperation.createWithResult(chainsData))
            stub.fetchData(from: evmAssetURL).thenReturn(BaseOperation.createWithResult(evmTokensData))
        }

        let startExpectation = XCTestExpectation()
        let completionExpectation = XCTestExpectation()

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if event is ChainSyncDidStart {
                    startExpectation.fulfill()
                }

                if event is ChainSyncDidComplete {
                    completionExpectation.fulfill()
                }
            }
        }

        chainService.syncUp()

        // then

        wait(for: [startExpectation, completionExpectation], timeout: 10, enforceOrder: true)

        let localItemsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([localItemsOperation], waitUntilFinished: true)

        let localItems = try localItemsOperation.extractNoCancellableResultData()

        XCTAssertEqual(chainService.isSyncing, false)
        XCTAssertEqual(Set(localItems), Set(expectedResult))
    }

    func testSyncDontRemoveUserAssets() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()

        let mapper = ChainModelMapper()
        let repository: CoreDataRepository<ChainModel, CDChain> =
            storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let operationQueue = OperationQueue()
        let eventCenter = MockEventCenterProtocol()
        let converter = ChainModelConverter()

        let chainService = ChainSyncService(
            url: chainURL,
            evmAssetsURL: evmAssetURL,
            chainConverter: ChainModelConverter(),
            dataFetchFactory: dataOperationFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            operationQueue: operationQueue
        )

        // when

        let remoteItems = ChainModelGenerator.generateRemote(count: 16)
        let localMappedItems = remoteItems.enumerated().compactMap { index, item in
            let localChain = converter.update(
                localModel: nil,
                remoteModel: item,
                additionalAssets: [],
                order: Int64(index)
            )

            let userAssetId = (localChain?.assets ?? []).count + 1
            let userAsset = ChainModelGenerator.generateAssetWithId(AssetModel.Id(userAssetId), source: .user)
            return localChain?.adding(asset: userAsset)
        }

        let chainsData = try JSONEncoder().encode(remoteItems)
        let evmTokensData = try JSONEncoder().encode([RemoteEvmToken]())

        stub(dataOperationFactory) { stub in
            stub.fetchData(from: chainURL).thenReturn(BaseOperation.createWithResult(chainsData))
            stub.fetchData(from: evmAssetURL).thenReturn(BaseOperation.createWithResult(evmTokensData))
        }

        let repositoryPresetOperation = repository.saveOperation({
            localMappedItems
        }, {
            []
        })

        operationQueue.addOperations([repositoryPresetOperation], waitUntilFinished: true)

        let startExpectation = XCTestExpectation()
        let completionExpectation = XCTestExpectation()

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if event is ChainSyncDidStart {
                    startExpectation.fulfill()
                }

                if event is ChainSyncDidComplete {
                    completionExpectation.fulfill()
                }
            }
        }

        chainService.syncUp()

        // then

        wait(for: [startExpectation, completionExpectation], timeout: 10, enforceOrder: true)

        let localItemsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([localItemsOperation], waitUntilFinished: true)

        let localItems = try localItemsOperation.extractNoCancellableResultData()

        XCTAssertEqual(Set(localItems), Set(localMappedItems))
    }

    func testSyncDontOverwriteUserSettings() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()

        let mapper = ChainModelMapper()
        let repository: CoreDataRepository<ChainModel, CDChain> =
            storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let operationQueue = OperationQueue()
        let eventCenter = MockEventCenterProtocol()
        let converter = ChainModelConverter()

        let chainService = ChainSyncService(
            url: chainURL,
            evmAssetsURL: evmAssetURL,
            chainConverter: ChainModelConverter(),
            dataFetchFactory: dataOperationFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            operationQueue: operationQueue
        )

        // when

        let remoteItems = ChainModelGenerator.generateRemote(count: 16)
        let initMappedItems = remoteItems.enumerated().map { index, item in
            let localChain = converter.update(
                localModel: nil,
                remoteModel: item,
                additionalAssets: [],
                order: Int64(index)
            )!

            var assets = Array(localChain.assets)
            assets[0] = assets[0].byChanging(enabled: false)

            return localChain.byChanging(assets: Set(assets))
        }

        // apply new name

        let updatedChains = zip(initMappedItems, remoteItems).map { localItem, remoteItem in
            let newName = UUID().uuidString

            let newLocalItem = localItem.byChanging(name: newName)
            let newRemoteItem = remoteItem.byChanging(name: newName)

            return (newLocalItem, newRemoteItem)
        }

        let newRemoteItems = updatedChains.map(\.1)
        let expectedLocalItems = updatedChains.map(\.0)

        let chainsData = try JSONEncoder().encode(newRemoteItems)
        let evmTokensData = try JSONEncoder().encode([RemoteEvmToken]())

        stub(dataOperationFactory) { stub in
            stub.fetchData(from: chainURL).thenReturn(BaseOperation.createWithResult(chainsData))
            stub.fetchData(from: evmAssetURL).thenReturn(BaseOperation.createWithResult(evmTokensData))
        }

        let repositoryPresetOperation = repository.saveOperation({
            initMappedItems
        }, {
            []
        })

        operationQueue.addOperations([repositoryPresetOperation], waitUntilFinished: true)

        let startExpectation = XCTestExpectation()
        let completionExpectation = XCTestExpectation()

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if event is ChainSyncDidStart {
                    startExpectation.fulfill()
                }

                if event is ChainSyncDidComplete {
                    completionExpectation.fulfill()
                }
            }
        }

        chainService.syncUp()

        // then

        wait(for: [startExpectation, completionExpectation], timeout: 10, enforceOrder: true)

        let localItemsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([localItemsOperation], waitUntilFinished: true)

        let localItems = try localItemsOperation.extractNoCancellableResultData()

        XCTAssertEqual(Set(localItems), Set(expectedLocalItems))
    }

    func testSyncDontOverwriteDisabledSyncMode() throws {
        try syncDontChangeLocal(
            initialLocalChainChange: { localItem in
                localItem.updatingSyncMode(for: .disabled)
            },
            updatedRemoteChainsChange: { $0 }
        )
    }

    func testSyncDontSyncUpdateChains() throws {
        try syncDontChangeLocal(
            initialLocalChainChange: { localItem in
                localItem.byChanging(source: .user)
            },
            updatedRemoteChainsChange: { remoteItems in
                remoteItems.map { remoteItem in
                    let newName = UUID().uuidString

                    return remoteItem.byChanging(name: newName)
                }
            }
        )
    }

    func testSyncDontRemoveUserChains() throws {
        try syncDontChangeLocal(
            initialLocalChainChange: { localItem in
                localItem.byChanging(source: .user)
            },
            updatedRemoteChainsChange: { Array($0.dropLast()) }
        )
    }

    func syncDontChangeLocal(
        initialLocalChainChange: (ChainModel) -> ChainModel,
        updatedRemoteChainsChange: ([RemoteChainModel]) -> [RemoteChainModel]
    ) throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()

        let mapper = ChainModelMapper()
        let repository: CoreDataRepository<ChainModel, CDChain> =
            storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let operationQueue = OperationQueue()
        let eventCenter = MockEventCenterProtocol()
        let converter = ChainModelConverter()

        let chainService = ChainSyncService(
            url: chainURL,
            evmAssetsURL: evmAssetURL,
            chainConverter: ChainModelConverter(),
            dataFetchFactory: dataOperationFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            operationQueue: operationQueue
        )

        // when
        let remoteItems = ChainModelGenerator.generateRemote(count: 16)
        let localItems = remoteItems.enumerated().map { index, item in
            let localChain = converter.update(
                localModel: nil,
                remoteModel: item,
                additionalAssets: [],
                order: Int64(index)
            )!

            var assets = Array(localChain.assets)
            assets[0] = assets[0].byChanging(enabled: false)

            return initialLocalChainChange(localChain.byChanging(assets: Set(assets)))
        }

        // update remote items

        let updatedRemoteItems = updatedRemoteChainsChange(remoteItems)

        let chainsData = try JSONEncoder().encode(updatedRemoteItems)
        let evmTokensData = try JSONEncoder().encode([RemoteEvmToken]())

        stub(dataOperationFactory) { stub in
            stub.fetchData(from: chainURL).thenReturn(BaseOperation.createWithResult(chainsData))
            stub.fetchData(from: evmAssetURL).thenReturn(BaseOperation.createWithResult(evmTokensData))
        }

        let repositoryPresetOperation = repository.saveOperation({
            localItems
        }, {
            []
        })

        operationQueue.addOperations([repositoryPresetOperation], waitUntilFinished: true)

        let startExpectation = XCTestExpectation()
        let completionExpectation = XCTestExpectation()

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if event is ChainSyncDidStart {
                    startExpectation.fulfill()
                }

                if event is ChainSyncDidComplete {
                    completionExpectation.fulfill()
                }
            }
        }

        chainService.syncUp()

        // then

        wait(for: [startExpectation, completionExpectation], timeout: 10, enforceOrder: true)

        let localItemsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([localItemsOperation], waitUntilFinished: true)

        let localItemsAfterSync = try localItemsOperation.extractNoCancellableResultData()

        XCTAssertEqual(Set(localItemsAfterSync), Set(localItems))
    }
}
