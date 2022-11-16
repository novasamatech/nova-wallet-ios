import XCTest
@testable import novawallet
import RobinHood
import Cuckoo

extension URL: Matchable {}

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
        let chainService = ChainSyncService(
            url: chainURL,
            evmAssetsURL: evmAssetURL,
            dataFetchFactory: dataOperationFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            operationQueue: operationQueue
        )
        
        // when
        
        let remoteItems = ChainModelGenerator.generateRemote(count: 16)
        let localMappedItems = remoteItems.enumerated().map { index, item in
            ChainModel(remoteModel: item, order: Int64(index))
        }
        
        let newItems = Array(localMappedItems[0..<8])
        let updatedItems = Array(localMappedItems[8..<13])
        let deletedItems = Array(localMappedItems[13..<16])
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
            deletedItems.map { $0.identifier }
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
        let chainService = ChainSyncService(
            url: chainURL,
            evmAssetsURL: evmAssetURL,
            dataFetchFactory: dataOperationFactory,
            repository: AnyDataProviderRepository(repository),
            eventCenter: eventCenter,
            operationQueue: operationQueue
        )
        
        // when
        
        let remoteItems = ChainModelGenerator.generateRemote(count: 3)
        let chainWithEvmTokens = remoteItems[0]
        let otherChainWithEvmTokens = remoteItems[1]
        let chainWithoutEvmTokens = remoteItems[2]
        let evmToken = ChainModelGenerator.generateEvmToken(chainId1: chainWithEvmTokens.chainId,
                                                            chainId2: otherChainWithEvmTokens.chainId)
        let usdChainAssets = [evmToken].chainAssets()
        
        let chainsData = try JSONEncoder().encode(remoteItems)
        let evmTokensData = try JSONEncoder().encode([evmToken])
        
        let expectedResult = [
            ChainModel(remoteModel: chainWithEvmTokens,
                       additionalAssets: usdChainAssets[chainWithEvmTokens.chainId]!,
                       order: 0),
            ChainModel(remoteModel: otherChainWithEvmTokens,
                       additionalAssets: usdChainAssets[otherChainWithEvmTokens.chainId]!,
                       order: 1),
            ChainModel(remoteModel: chainWithoutEvmTokens, order: 2)
        ]
        
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
}
