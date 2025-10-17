import XCTest
@testable import novawallet
import Operation_iOS

final class NominationPoolsApyTests: XCTestCase {
    func testMaxApyCalculation() throws {
        let calculator = try fetchRewardEngine(for: KnowChainId.polkadot)

        let maxApy = try calculator.calculateMaxReturn(isCompound: true, period: .year)

        Logger.shared.info("Polkadot max apy: \(maxApy.maxApy.stringWithPointSeparator)")
    }

    func testApyForNovaPool() throws {
        let calculator = try fetchRewardEngine(for: KnowChainId.polkadot)

        let maxApy = try calculator.calculateMaxReturn(poolId: 54, isCompound: true, period: .year)

        Logger.shared.info("Nova pool apy: \(maxApy.maxApy.stringWithPointSeparator)")
    }

    func testApyForMaxPool() throws {
        let calculator = try fetchRewardEngine(for: KnowChainId.polkadot)

        let maxApy = try calculator.calculateMaxReturn(isCompound: true, period: .year)

        Logger.shared.info("Pool apy: \(maxApy.maxApy.stringWithPointSeparator)")
    }

    private func fetchRewardEngine(for chainId: ChainModel.Id) throws -> NominationPoolsRewardEngineProtocol {
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

        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactory(
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
            providerFactory: stakingLocalSubscriptionFactory,
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

        let validatorRewardCalculatorService = try StakingServiceFactory(
            chainRegisty: chainRegistry,
            storageFacade: storageFacade,
            eventCenter: EventCenter.shared,
            operationQueue: operationQueue,
            logger: Logger.shared
        ).createRewardCalculatorService(
            for: chainAsset,
            stakingType: .relaychain,
            stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactory(
                chainRegistry: chainRegistry,
                storageFacade: storageFacade,
                operationManager: OperationManager(operationQueue: operationQueue),
                logger: Logger.shared
            ),
            stakingDurationFactory: BabeStakingDurationFactory(
                chainId: chainId,
                chainRegistry: chainRegistry
            ),
            validatorService: eraValidatorService
        )

        let rewardEngineFactory = NPoolsRewardEngineFactory(operationFactory: npOperationFactory)

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
        validatorRewardCalculatorService.setup()

        // when

        let wrapper = rewardEngineFactory.createEngineWrapper(
            for: nominationPoolsService,
            validatorRewardService: validatorRewardCalculatorService,
            connection: connection,
            runtimeService: runtimeService
        )

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        // then

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

        validatorRewardCalculatorService.throttle()

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
