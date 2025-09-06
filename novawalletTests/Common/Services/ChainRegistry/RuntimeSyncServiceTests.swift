import XCTest
@testable import novawallet
import Cuckoo
import Operation_iOS

class RuntimeSyncServiceTests: XCTestCase {
    func testChainRegisterationAndUnregistration() {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let metadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            storageFacade.createRepository()
        let filesOperationFactory = MockRuntimeFilesOperationFactoryProtocol()
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let eventCenter = MockEventCenterProtocol()
        let connection = MockConnection()

        let operationQueue = OperationQueue()

        let syncService = RuntimeSyncService(
            repository: AnyDataProviderRepository(metadataRepository),
            runtimeFetchFactory: MockRuntimeFetchOperationFactory(),
            runtimeLocalMigrator: RuntimeLocalMigrator.createLatest(),
            filesOperationFactory: filesOperationFactory,
            dataOperationFactory: dataOperationFactory,
            eventCenter: eventCenter,
            operationQueue: operationQueue
        )

        let chainCount = 10
        let chains = ChainModelGenerator.generate(count: chainCount)

        let unregisterChains = Set(chains.prefix(chainCount / 2))
        let remainingChains = Set(chains.suffix(chains.count - unregisterChains.count))

        // when

        chains.forEach { syncService.register(chain: $0, with: connection) }

        // then

        XCTAssertTrue(chains.allSatisfy { syncService.hasChain(with: $0.chainId) })
        XCTAssertTrue(chains.allSatisfy { !syncService.isChainSyncing($0.chainId) })

        // when

        unregisterChains.forEach { syncService.unregisterIfExists(chainId: $0.chainId) }

        // then

        XCTAssertTrue(remainingChains.allSatisfy { syncService.hasChain(with: $0.chainId) })
        XCTAssertTrue(unregisterChains.allSatisfy { !syncService.hasChain(with: $0.chainId) })
    }

    func testTypesAndMetadataSyncSuccess() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let metadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            storageFacade.createRepository()
        let filesOperationFactory = MockRuntimeFilesOperationFactoryProtocol()
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let eventCenter = MockEventCenterProtocol()

        // when

        let chainCount = 10
        let chains = ChainModelGenerator.generate(count: chainCount)

        let connections = chains.reduce(into: [ChainModel.Id: MockConnection]()) { storage, chain in
            storage[chain.chainId] = MockConnection()
        }

        let runtimeMetadataItems = chains.reduce(into: [ChainModel.Id: RawRuntimeMetadata]()) { storage, chain in
            storage[chain.chainId] = RawRuntimeMetadata(
                content: Data.random(of: 128)!,
                isOpaque: false
            )
        }

        let syncService = RuntimeSyncService(
            repository: AnyDataProviderRepository(metadataRepository),
            runtimeFetchFactory: MockRuntimeFetchOperationFactory(
                rawMetadataDict: runtimeMetadataItems
            ),
            runtimeLocalMigrator: RuntimeLocalMigrator.createLatest(),
            filesOperationFactory: filesOperationFactory,
            dataOperationFactory: dataOperationFactory,
            eventCenter: eventCenter,
            operationQueue: OperationQueue()
        )

        // stub chain types file fetch from remote source

        stub(dataOperationFactory) { stub in
            stub.fetchData(from: any()).then { _ in
                let responseData = Data.random(of: 1024)!
                return BaseOperation.createWithResult(responseData)
            }
        }

        // stub chain types file save to disk

        stub(filesOperationFactory) { stub in
            stub.saveChainTypesOperation(for: any(), data: any()).then { _, _ in
                CompoundOperationWrapper.createWithResult(())
            }
        }

        let completionExpectation = XCTestExpectation()
        completionExpectation.expectedFulfillmentCount = 2 * chainCount
        completionExpectation.assertForOverFulfill = true

        var syncedTypesChainIds: Set<ChainModel.Id> = Set()
        var syncedMetadataChainIds: Set<ChainModel.Id> = Set()

        // catch all sync completion events

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if let syncEvent = event as? RuntimeChainTypesSyncCompleted {
                    syncedTypesChainIds.insert(syncEvent.chainId)
                }

                if let syncEvent = event as? RuntimeMetadataSyncCompleted {
                    syncedMetadataChainIds.insert(syncEvent.chainId)
                }

                completionExpectation.fulfill()
            }
        }

        chains.forEach { chain in
            syncService.register(chain: chain, with: connections[chain.chainId]!)
            syncService.apply(
                version: RuntimeVersion(specVersion: 1, transactionVersion: 1),
                for: chain.chainId
            )

            XCTAssertTrue(syncService.isChainSyncing(chain.chainId))
        }

        // then

        wait(for: [completionExpectation], timeout: 10)

        let expectedChainIds = Set(chains.map(\.chainId))

        XCTAssertEqual(expectedChainIds, syncedTypesChainIds)
        XCTAssertEqual(expectedChainIds, syncedMetadataChainIds)

        // make sure files are saved

        verify(filesOperationFactory, times(chainCount)).saveChainTypesOperation(for: any(), data: any())

        // make sure metadata is saved for each chain

        let allMetadataOperation = metadataRepository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([allMetadataOperation], waitUntilFinished: true)

        let actualMetadataItems = try allMetadataOperation.extractNoCancellableResultData()
        XCTAssertEqual(actualMetadataItems.count, chainCount)

        for actualMetadataItem in actualMetadataItems {
            XCTAssertEqual(actualMetadataItem.metadata, runtimeMetadataItems[actualMetadataItem.chain]!.content)
            XCTAssertEqual(actualMetadataItem.opaque, runtimeMetadataItems[actualMetadataItem.chain]!.isOpaque)
        }
    }

    func testOnlyMetadataSyncSuccess() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let metadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            storageFacade.createRepository()
        let filesOperationFactory = MockRuntimeFilesOperationFactoryProtocol()
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let eventCenter = MockEventCenterProtocol()

        // when

        let chainCount = 10
        let chains = ChainModelGenerator.generate(count: chainCount, withTypes: false)

        let connections = chains.reduce(into: [ChainModel.Id: MockConnection]()) { storage, chain in
            storage[chain.chainId] = MockConnection()
        }

        let runtimeMetadataItems = chains.reduce(into: [ChainModel.Id: RawRuntimeMetadata]()) { storage, chain in
            storage[chain.chainId] = RawRuntimeMetadata(content: Data.random(of: 128)!, isOpaque: true)
        }

        let syncService = RuntimeSyncService(
            repository: AnyDataProviderRepository(metadataRepository),
            runtimeFetchFactory: MockRuntimeFetchOperationFactory(
                rawMetadataDict: runtimeMetadataItems
            ),
            runtimeLocalMigrator: RuntimeLocalMigrator.createLatest(),
            filesOperationFactory: filesOperationFactory,
            dataOperationFactory: dataOperationFactory,
            eventCenter: eventCenter,
            operationQueue: OperationQueue()
        )

        let completionExpectation = XCTestExpectation()
        completionExpectation.expectedFulfillmentCount = chainCount
        completionExpectation.assertForOverFulfill = true

        var syncedMetadataChainIds: Set<ChainModel.Id> = Set()

        // catch all sync completion events

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if let syncEvent = event as? RuntimeMetadataSyncCompleted {
                    syncedMetadataChainIds.insert(syncEvent.chainId)
                }

                completionExpectation.fulfill()
            }
        }

        chains.forEach { chain in
            syncService.register(chain: chain, with: connections[chain.chainId]!)
            syncService.apply(
                version: RuntimeVersion(specVersion: 1, transactionVersion: 1),
                for: chain.chainId
            )

            XCTAssertTrue(syncService.isChainSyncing(chain.chainId))
        }

        // then

        wait(for: [completionExpectation], timeout: 10)

        let expectedChainIds = Set(chains.map(\.chainId))

        XCTAssertEqual(expectedChainIds, syncedMetadataChainIds)

        // make sure metadata is saved for each chain

        let allMetadataOperation = metadataRepository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([allMetadataOperation], waitUntilFinished: true)

        let actualMetadataItems = try allMetadataOperation.extractNoCancellableResultData()
        XCTAssertEqual(actualMetadataItems.count, chainCount)

        for actualMetadataItem in actualMetadataItems {
            XCTAssertEqual(actualMetadataItem.metadata, runtimeMetadataItems[actualMetadataItem.chain]!.content)
            XCTAssertEqual(actualMetadataItem.opaque, runtimeMetadataItems[actualMetadataItem.chain]!.isOpaque)
        }
    }

    func testTypesAndMetadataFailureRetry() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let metadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            storageFacade.createRepository()
        let filesOperationFactory = MockRuntimeFilesOperationFactoryProtocol()
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let eventCenter = MockEventCenterProtocol()

        // when

        let chainCount = 10
        let chains = ChainModelGenerator.generate(count: chainCount)

        let connections = chains.reduce(into: [ChainModel.Id: MockConnection]()) { storage, chain in
            storage[chain.chainId] = MockConnection()
        }

        let runtimeMetadataItems = chains.reduce(into: [ChainModel.Id: RawRuntimeMetadata]()) { storage, chain in
            storage[chain.chainId] = RawRuntimeMetadata(
                content: Data.random(of: 128)!,
                isOpaque: false
            )
        }

        // stub runtime metadata fetch

        var failureCounterForMetadata: Int = 0

        let runtimeFetchFactory = MockRuntimeFetchOperationFactory { chainId in
            if failureCounterForMetadata < chainCount {
                failureCounterForMetadata += 1

                throw CommonError.dataCorruption
            } else {
                return runtimeMetadataItems[chainId]!
            }
        }

        let syncService = RuntimeSyncService(
            repository: AnyDataProviderRepository(metadataRepository),
            runtimeFetchFactory: runtimeFetchFactory,
            runtimeLocalMigrator: RuntimeLocalMigrator.createLatest(),
            filesOperationFactory: filesOperationFactory,
            dataOperationFactory: dataOperationFactory,
            eventCenter: eventCenter,
            operationQueue: OperationQueue()
        )

        // stub chain types file fetch from remote source

        var failureCounterForTypes: Int = 0

        stub(dataOperationFactory) { stub in
            stub.fetchData(from: any()).then { _ in
                if failureCounterForTypes < chainCount {
                    failureCounterForTypes += 1

                    return BaseOperation.createWithError(BaseOperationError.unexpectedDependentResult)
                } else {
                    let responseData = Data.random(of: 1024)!
                    return BaseOperation.createWithResult(responseData)
                }
            }
        }

        // stub chain types file save to disk

        stub(filesOperationFactory) { stub in
            stub.saveChainTypesOperation(for: any(), data: any()).then { _, _ in
                CompoundOperationWrapper.createWithResult(())
            }
        }

        let completionExpectation = XCTestExpectation()
        completionExpectation.expectedFulfillmentCount = 2 * chainCount
        completionExpectation.assertForOverFulfill = true

        var syncedTypesChainIds: Set<ChainModel.Id> = Set()
        var syncedMetadataChainIds: Set<ChainModel.Id> = Set()

        // catch all sync completion events

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if let syncEvent = event as? RuntimeChainTypesSyncCompleted {
                    syncedTypesChainIds.insert(syncEvent.chainId)
                }

                if let syncEvent = event as? RuntimeMetadataSyncCompleted {
                    syncedMetadataChainIds.insert(syncEvent.chainId)
                }

                completionExpectation.fulfill()
            }
        }

        chains.forEach { chain in
            syncService.register(chain: chain, with: connections[chain.chainId]!)
            syncService.apply(
                version: RuntimeVersion(specVersion: 1, transactionVersion: 1),
                for: chain.chainId
            )

            XCTAssertTrue(syncService.isChainSyncing(chain.chainId))
        }

        // then

        wait(for: [completionExpectation], timeout: 10)

        let expectedChainIds = Set(chains.map(\.chainId))

        XCTAssertEqual(expectedChainIds, syncedTypesChainIds)
        XCTAssertEqual(expectedChainIds, syncedMetadataChainIds)

        // make sure files are tried to be save twice (first time and after retry)

        verify(filesOperationFactory, times(2 * chainCount)).saveChainTypesOperation(
            for: any(),
            data: any()
        )

        // make sure metadata is saved for each chain

        let allMetadataOperation = metadataRepository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([allMetadataOperation], waitUntilFinished: true)

        let actualMetadataItems = try allMetadataOperation.extractNoCancellableResultData()
        XCTAssertEqual(actualMetadataItems.count, chainCount)

        for actualMetadataItem in actualMetadataItems {
            XCTAssertEqual(actualMetadataItem.metadata, runtimeMetadataItems[actualMetadataItem.chain]!.content)
            XCTAssertEqual(actualMetadataItem.opaque, runtimeMetadataItems[actualMetadataItem.chain]!.isOpaque)
        }
    }

    func testOnlyTypesFailureRetry() throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let metadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            storageFacade.createRepository()
        let filesOperationFactory = MockRuntimeFilesOperationFactoryProtocol()
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let eventCenter = MockEventCenterProtocol()

        // when

        let chainCount = 10
        let chains = ChainModelGenerator.generate(count: chainCount)

        let connections = chains.reduce(into: [ChainModel.Id: MockConnection]()) { storage, chain in
            storage[chain.chainId] = MockConnection()
        }

        let runtimeMetadataItems = chains.reduce(into: [ChainModel.Id: RawRuntimeMetadata]()) { storage, chain in
            storage[chain.chainId] = RawRuntimeMetadata(content: Data.random(of: 128)!, isOpaque: false)
        }

        let runtimeFetcherFactory = MockRuntimeFetchOperationFactory(rawMetadataDict: runtimeMetadataItems)
        let syncService = RuntimeSyncService(
            repository: AnyDataProviderRepository(metadataRepository),
            runtimeFetchFactory: runtimeFetcherFactory,
            runtimeLocalMigrator: RuntimeLocalMigrator.createLatest(),
            filesOperationFactory: filesOperationFactory,
            dataOperationFactory: dataOperationFactory,
            eventCenter: eventCenter,
            operationQueue: OperationQueue()
        )

        // stub chain types file fetch from remote source

        var failureCounterForTypes: Int = 0

        stub(dataOperationFactory) { stub in
            stub.fetchData(from: any()).then { _ in
                if failureCounterForTypes < chainCount {
                    failureCounterForTypes += 1

                    return BaseOperation.createWithError(BaseOperationError.unexpectedDependentResult)
                } else {
                    let responseData = Data.random(of: 1024)!
                    return BaseOperation.createWithResult(responseData)
                }
            }
        }

        // stub chain types file save to disk

        stub(filesOperationFactory) { stub in
            stub.saveChainTypesOperation(for: any(), data: any()).then { _, _ in
                CompoundOperationWrapper.createWithResult(())
            }
        }

        let completionExpectation = XCTestExpectation()
        completionExpectation.expectedFulfillmentCount = 2 * chainCount
        completionExpectation.assertForOverFulfill = true

        var syncedTypesChainIds: Set<ChainModel.Id> = Set()
        var syncedMetadataChainIds: Set<ChainModel.Id> = Set()

        // catch all sync completion events

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if let syncEvent = event as? RuntimeChainTypesSyncCompleted {
                    syncedTypesChainIds.insert(syncEvent.chainId)
                }

                if let syncEvent = event as? RuntimeMetadataSyncCompleted {
                    syncedMetadataChainIds.insert(syncEvent.chainId)
                }

                completionExpectation.fulfill()
            }
        }

        chains.forEach { chain in
            syncService.register(chain: chain, with: connections[chain.chainId]!)
            syncService.apply(
                version: RuntimeVersion(specVersion: 1, transactionVersion: 1),
                for: chain.chainId
            )

            XCTAssertTrue(syncService.isChainSyncing(chain.chainId))
        }

        // then

        wait(for: [completionExpectation], timeout: 10)

        let expectedChainIds = Set(chains.map(\.chainId))

        XCTAssertEqual(expectedChainIds, syncedTypesChainIds)
        XCTAssertEqual(expectedChainIds, syncedMetadataChainIds)

        // make sure files are tried to be save twice (first time and after retry)

        verify(filesOperationFactory, times(2 * chainCount)).saveChainTypesOperation(
            for: any(),
            data: any()
        )

        // make sure metadata requested once

        for chain in chains {
            XCTAssertEqual(runtimeFetcherFactory.getRequestsCount(for: chain.chainId), 1)
        }

        // make sure metadata is saved for each chain

        let allMetadataOperation = metadataRepository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([allMetadataOperation], waitUntilFinished: true)

        let actualMetadataItems = try allMetadataOperation.extractNoCancellableResultData()
        XCTAssertEqual(actualMetadataItems.count, chainCount)

        for actualMetadataItem in actualMetadataItems {
            XCTAssertEqual(actualMetadataItem.metadata, runtimeMetadataItems[actualMetadataItem.chain]!.content)
            XCTAssertEqual(actualMetadataItem.opaque, runtimeMetadataItems[actualMetadataItem.chain]!.isOpaque)
        }
    }

    func testNoMetadataSyncRequired() throws {
        try performMetadataSyncTest(
            currentSpecVersion: 2,
            newSpecVersion: 2,
            currentLocalMigratorVersion: 3,
            newLocalMigratorVersion: 3
        )
    }

    func testMetadataSyncChangeDueToSpecVersion() throws {
        try performMetadataSyncTest(
            currentSpecVersion: 2,
            newSpecVersion: 4,
            currentLocalMigratorVersion: 3,
            newLocalMigratorVersion: 3
        )
    }

    func testMetadataSyncChangeDueToLocalMigratoVersion() throws {
        try performMetadataSyncTest(
            currentSpecVersion: 2,
            newSpecVersion: 2,
            currentLocalMigratorVersion: 3,
            newLocalMigratorVersion: 4
        )
    }

    func testMetadataSyncChangeDueToBothSpecLocalMigratoVersion() throws {
        try performMetadataSyncTest(
            currentSpecVersion: 2,
            newSpecVersion: 3,
            currentLocalMigratorVersion: 3,
            newLocalMigratorVersion: 4
        )
    }

    private func performMetadataSyncTest(
        currentSpecVersion: UInt32,
        newSpecVersion: UInt32,
        currentLocalMigratorVersion: UInt32,
        newLocalMigratorVersion: UInt32
    ) throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let metadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            storageFacade.createRepository()
        let filesOperationFactory = MockRuntimeFilesOperationFactoryProtocol()
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let eventCenter = MockEventCenterProtocol()
        let operationQueue = OperationQueue()

        // when

        let chainCount = 10
        let chains = ChainModelGenerator.generate(count: chainCount)

        let connections = chains.reduce(into: [ChainModel.Id: MockConnection]()) { storage, chain in
            storage[chain.chainId] = MockConnection()
        }

        let oldRuntimeMetadataItems = chains.reduce(into: [ChainModel.Id: RawRuntimeMetadata]()) { storage, chain in
            storage[chain.chainId] = RawRuntimeMetadata(content: Data.random(of: 128)!, isOpaque: false)
        }

        save(
            runtimes: oldRuntimeMetadataItems,
            in: AnyDataProviderRepository(metadataRepository),
            specVersion: currentSpecVersion,
            localMigratorVersion: currentLocalMigratorVersion
        )

        let newRuntimeMetadataItems = chains.reduce(into: [ChainModel.Id: RawRuntimeMetadata]()) { storage, chain in
            storage[chain.chainId] = RawRuntimeMetadata(content: Data.random(of: 128)!, isOpaque: false)
        }

        let runtimeFetcherFactory = MockRuntimeFetchOperationFactory(rawMetadataDict: newRuntimeMetadataItems)
        let syncService = RuntimeSyncService(
            repository: AnyDataProviderRepository(metadataRepository),
            runtimeFetchFactory: runtimeFetcherFactory,
            runtimeLocalMigrator: RuntimeLocalMigrator(version: newLocalMigratorVersion),
            filesOperationFactory: filesOperationFactory,
            dataOperationFactory: dataOperationFactory,
            eventCenter: eventCenter,
            operationQueue: operationQueue
        )

        stubTypesLoading(dataOperationFactory: dataOperationFactory, filesOperationFactory: filesOperationFactory)

        // then

        waitSyncAndVerify(
            for: chains,
            connections: connections,
            version: RuntimeVersion(specVersion: newSpecVersion, transactionVersion: 1),
            eventCenter: eventCenter,
            syncService: syncService
        )

        let changesExpected = currentSpecVersion != newSpecVersion || currentLocalMigratorVersion != newLocalMigratorVersion

        try expect(
            runtimeMetadataItems: changesExpected ? newRuntimeMetadataItems : oldRuntimeMetadataItems,
            in: AnyDataProviderRepository(metadataRepository),
            specVersion: newSpecVersion,
            localMigratorVersion: newLocalMigratorVersion
        )

        for chain in chains {
            XCTAssertEqual(runtimeFetcherFactory.getRequestsCount(for: chain.chainId), changesExpected ? 1 : 0)
        }
    }

    private func stubTypesLoading(
        dataOperationFactory: MockDataOperationFactoryProtocol,
        filesOperationFactory: MockRuntimeFilesOperationFactoryProtocol
    ) {
        stub(dataOperationFactory) { stub in
            stub.fetchData(from: any()).then { _ in
                let responseData = Data.random(of: 1024)!
                return BaseOperation.createWithResult(responseData)
            }
        }

        stub(filesOperationFactory) { stub in
            stub.saveChainTypesOperation(for: any(), data: any()).then { _, _ in
                CompoundOperationWrapper.createWithResult(())
            }
        }
    }

    private func waitSyncAndVerify(
        for chains: [ChainModel],
        connections: [ChainModel.Id: MockConnection],
        version: RuntimeVersion,
        eventCenter: MockEventCenterProtocol,
        syncService: RuntimeSyncServiceProtocol
    ) {
        let completionExpectation = XCTestExpectation()
        completionExpectation.expectedFulfillmentCount = 2 * chains.count // one for types and one for metadata
        completionExpectation.assertForOverFulfill = true

        var syncedMetadataChainIds: Set<ChainModel.Id> = Set()

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if let syncEvent = event as? RuntimeMetadataSyncCompleted {
                    syncedMetadataChainIds.insert(syncEvent.chainId)
                }

                completionExpectation.fulfill()
            }
        }

        chains.forEach { chain in
            syncService.register(chain: chain, with: connections[chain.chainId]!)
            syncService.apply(
                version: version,
                for: chain.chainId
            )

            XCTAssertTrue(syncService.isChainSyncing(chain.chainId))
        }

        wait(for: [completionExpectation], timeout: 10)

        let expectedChainIds = Set(chains.map(\.chainId))

        XCTAssertEqual(expectedChainIds, syncedMetadataChainIds)
    }

    private func save(
        runtimes: [ChainModel.Id: RawRuntimeMetadata],
        in repository: AnyDataProviderRepository<RuntimeMetadataItem>,
        specVersion: UInt32,
        localMigratorVersion: UInt32
    ) {
        let runtimeMetadataItems: [RuntimeMetadataItem] = runtimes.map { chainId, metadata in
            RuntimeMetadataItem(
                chain: chainId,
                version: specVersion,
                txVersion: 1,
                localMigratorVersion: localMigratorVersion,
                opaque: metadata.isOpaque,
                metadata: metadata.content
            )
        }

        let saveOperation = repository.saveOperation({ runtimeMetadataItems }, { [] })

        OperationQueue().addOperations([saveOperation], waitUntilFinished: true)
    }

    private func expect(
        runtimeMetadataItems: [ChainModel.Id: RawRuntimeMetadata],
        in repository: AnyDataProviderRepository<RuntimeMetadataItem>,
        specVersion: UInt32,
        localMigratorVersion: UInt32
    ) throws {
        let allMetadataOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        OperationQueue().addOperations([allMetadataOperation], waitUntilFinished: true)

        let actualMetadataItems = try allMetadataOperation.extractNoCancellableResultData()
        XCTAssertEqual(actualMetadataItems.count, runtimeMetadataItems.count)

        for actualMetadataItem in actualMetadataItems {
            XCTAssertEqual(actualMetadataItem.metadata, runtimeMetadataItems[actualMetadataItem.chain]?.content)
            XCTAssertEqual(actualMetadataItem.opaque, runtimeMetadataItems[actualMetadataItem.chain]?.isOpaque)
            XCTAssertEqual(actualMetadataItem.version, specVersion)
            XCTAssertEqual(actualMetadataItem.localMigratorVersion, localMigratorVersion)
        }
    }
}
