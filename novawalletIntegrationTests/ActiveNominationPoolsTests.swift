import XCTest
@testable import novawallet
import Operation_iOS

final class ActiveNominationPoolsTests: XCTestCase {
    func testPolkadotPools() throws {
        try performActivePoolsTest(for: KnowChainId.polkadot)
    }

    private func performActivePoolsTest(for chainId: ChainModel.Id) throws {
        // given

        let storageFacade = SubstrateStorageTestFacade()

        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let asset = chain.utilityAsset(),
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.noChain(chainId)
        }

        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let operationQueue = OperationQueue()

        let substrateRepositoryFactory = SubstrateRepositoryFactory(storageFacade: storageFacade)
        let substrateDataProviderFactory = StakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManager(operationQueue: operationQueue),
            logger: Logger.shared
        )

        let eraValidatorService = EraValidatorService(
            chainId: chainId,
            storageFacade: storageFacade,
            runtimeCodingService: runtimeService,
            connection: connection,
            providerFactory: substrateDataProviderFactory,
            operationQueue: operationQueue,
            eventCenter: EventCenter.shared,
            logger: Logger.shared
        )

        let npRemoteSubscriptionService = NominationPoolsRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: substrateRepositoryFactory.createChainStorageItemRepository(),
            syncOperationManager: OperationManager(operationQueue: operationQueue),
            repositoryOperationManager: OperationManager(operationQueue: operationQueue),
            logger: Logger.shared
        )

        let relaychainSubscriptionService = StakingRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: substrateRepositoryFactory.createChainStorageItemRepository(),
            syncOperationManager: OperationManager(operationQueue: operationQueue),
            repositoryOperationManager: OperationManager(operationQueue: operationQueue),
            logger: Logger.shared
        )

        let npOperationFactory = NominationPoolsOperationFactory(operationQueue: operationQueue)
        let npDataProviderFactory = NPoolsLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let nominationPoolsService = EraNominationPoolsService(
            chainAsset: chainAsset,
            runtimeCodingService: runtimeService,
            operationFactory: npOperationFactory,
            npoolsLocalSubscriptionFactory: npDataProviderFactory,
            eraValidatorService: eraValidatorService,
            operationQueue: operationQueue
        )

        let npSubscriptionId = npRemoteSubscriptionService.attachToGlobalData(
            for: chainId,
            queue: nil,
            closure: nil
        )

        let relaychainSubscriptionId = relaychainSubscriptionService.attachToGlobalData(
            for: chainId,
            queue: nil,
            closure: nil
        )

        eraValidatorService.setup()
        nominationPoolsService.setup()

        // when

        let operation = nominationPoolsService.fetchInfoOperation()

        operationQueue.addOperations([operation], waitUntilFinished: true)

        // then

        do {
            let activePools = try operation.extractNoCancellableResultData()
            Logger.shared.info("Active pools: \(activePools)")
        } catch {
            XCTFail("Can't get active pools: \(error)")
        }

        npRemoteSubscriptionService.detachFromGlobalData(
            for: npSubscriptionId!,
            chainId: chainId,
            queue: nil,
            closure: nil
        )

        relaychainSubscriptionService.detachFromGlobalData(
            for: relaychainSubscriptionId!,
            chainId: chainId,
            queue: nil,
            closure: nil
        )

        eraValidatorService.throttle()
    }
}
