import XCTest
@testable import novawallet
import RobinHood

class ParachainStakingCollatorsTests: XCTestCase {
    func testRemoteSyncCompletes() throws {
        let chainId = "401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b"

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard let collators = try syncCollators(
            for: chainId,
            storageFacade: storageFacade,
            chainRegistry: chainRegistry
        ) else {
            XCTFail("Can't sync collators")
            return
        }

        let savedCollatorsCount = try fetchCollatorsCount(for: chainId, storageFacade: storageFacade)

        XCTAssert(!collators.validators.isEmpty)
        XCTAssertEqual(savedCollatorsCount, collators.validators.count)
    }

    func testRemoteSyncAndLocalFetch() throws {
        let chainId = "401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b"

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard let remoteCollators = try syncCollators(
            for: chainId,
            storageFacade: storageFacade,
            chainRegistry: chainRegistry
        ) else {
            XCTFail("Can't sync remote collators")
            return
        }

        guard let localCollators = try syncCollators(
            for: chainId,
            storageFacade: storageFacade,
            chainRegistry: chainRegistry
        ) else {
            XCTFail("Can't sync remote collators")
            return
        }

        XCTAssertEqual(remoteCollators.activeEra, localCollators.activeEra)
        XCTAssertEqual(remoteCollators.validators.count, localCollators.validators.count)
    }

    private func fetchCollatorsCount(
        for chainId: ChainModel.Id,
        storageFacade: StorageFacadeProtocol
    ) throws -> Int {
        let prefixKey = try LocalStorageKeyFactory().createRestorableKey(
            from: ParachainStaking.atStakePath,
            chainId: chainId
        )

        let filter = NSPredicate.filterByIdPrefix(prefixKey)

        let repository = SubstrateRepositoryFactory(
            storageFacade: storageFacade
        ).createChainStorageItemRepository(filter: filter)

        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData().count
    }

    private func syncCollators(
        for chainId: ChainModel.Id,
        storageFacade: StorageFacadeProtocol,
        chainRegistry: ChainRegistryProtocol
    ) throws -> EraStakersInfo? {
        guard
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            return nil
        }

        let operationQueue = OperationQueue()
        let operationManager = OperationManager(operationQueue: operationQueue)
        let logger = Logger.shared

        let repository = SubstrateRepositoryFactory(storageFacade: storageFacade)
            .createChainStorageItemRepository()
        let remoteSubscription = ParachainStaking.StakingRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: repository,
            operationManager: operationManager,
            logger: logger
        )

        guard let subscriptionId = remoteSubscription.attachToGlobalData(
            for: chainId,
            queue: nil,
            closure: nil
        ) else {
            return nil
        }

        let providerFactory = ParachainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManager(operationQueue: operationQueue),
            logger: logger
        )

        let collatorService = ParachainStakingCollatorService(
            chainId: chainId,
            storageFacade: storageFacade,
            runtimeCodingService: runtimeService,
            connection: connection,
            providerFactory: providerFactory,
            operationQueue: operationQueue,
            eventCenter: EventCenter.shared,
            logger: logger
        )

        collatorService.setup()

        let collatorsOperation = collatorService.fetchInfoOperation()

        operationQueue.addOperations([collatorsOperation], waitUntilFinished: true)

        remoteSubscription.detachFromGlobalData(
            for: subscriptionId,
            chainId: chainId,
            queue: nil,
            closure: nil
        )

        return try collatorsOperation.extractNoCancellableResultData()
    }
}
