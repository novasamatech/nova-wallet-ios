import XCTest
@testable import novawallet
import RobinHood

class ParachainStakingCollatorsTests: XCTestCase {
    func testSyncCompletes() {
        let chainId = "401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b"

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            XCTFail("Can't get connection or runtime service")
            return
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
            XCTFail("Can't subscribe to parachain staking data")
            return
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
    }
}
