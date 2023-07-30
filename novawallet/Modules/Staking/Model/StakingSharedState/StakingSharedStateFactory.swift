import Foundation
import SubstrateSdk
import RobinHood

protocol StakingSharedStateFactoryProtocol {
    func createRelaychain(
        for stakingOption: Multistaking.ChainAssetOption
    ) throws -> RelaychainStakingSharedStateProtocol

    func createParachain(
        for stakingOption: Multistaking.ChainAssetOption
    ) throws -> ParachainStakingSharedStateProtocol
}

enum StakingSharedStateFactoryError: Error {
    case unsupported
    case noBlockTimeService
}

final class StakingSharedStateFactory {
    let storageFacade: StorageFacadeProtocol
    let chainRegistry: ChainRegistryProtocol
    let eventCenter: EventCenterProtocol
    let syncOperationQueue: OperationQueue
    let repositoryOperationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        storageFacade: StorageFacadeProtocol,
        chainRegistry: ChainRegistryProtocol,
        eventCenter: EventCenterProtocol,
        syncOperationQueue: OperationQueue,
        repositoryOperationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.storageFacade = storageFacade
        self.chainRegistry = chainRegistry
        self.eventCenter = eventCenter
        self.syncOperationQueue = syncOperationQueue
        self.repositoryOperationQueue = repositoryOperationQueue
        self.logger = logger
    }

    func createStakingDuration(
        for consensus: ConsensusType,
        chain: ChainModel,
        blockTimeService: BlockTimeEstimationServiceProtocol
    ) -> StakingDurationOperationFactoryProtocol {
        switch consensus {
        case .babe:
            return BabeStakingDurationFactory()
        case .aura:
            return AuraStakingDurationFactory(
                blockTimeService: blockTimeService,
                blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain)
            )
        }
    }
}

extension StakingSharedStateFactory: StakingSharedStateFactoryProtocol {
    // swiftlint:disable:next function_body_length
    func createRelaychain(
        for stakingOption: Multistaking.ChainAssetOption
    ) throws -> RelaychainStakingSharedStateProtocol {
        guard let consensus = ConsensusType(stakingType: stakingOption.type) else {
            throw StakingSharedStateFactoryError.unsupported
        }

        let substrateRepositoryFactory = SubstrateRepositoryFactory(storageFacade: storageFacade)

        let substrateRepository = substrateRepositoryFactory.createChainStorageItemRepository()
        let globalRemoteSubscriptionService = StakingRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: substrateRepository,
            syncOperationManager: OperationManager(operationQueue: syncOperationQueue),
            repositoryOperationManager: OperationManager(operationQueue: repositoryOperationQueue),
            logger: logger
        )

        let substrateDataProviderFactory = SubstrateDataProviderFactory(
            facade: storageFacade,
            operationManager: OperationManager(operationQueue: repositoryOperationQueue)
        )

        let childSubscriptionFactory = ChildSubscriptionFactory(
            storageFacade: storageFacade,
            operationManager: OperationManager(operationQueue: repositoryOperationQueue),
            eventCenter: eventCenter,
            logger: logger
        )

        let accountRemoteSubscriptionService = StakingAccountUpdatingService(
            chainRegistry: chainRegistry,
            substrateRepositoryFactory: substrateRepositoryFactory,
            substrateDataProviderFactory: substrateDataProviderFactory,
            childSubscriptionFactory: childSubscriptionFactory,
            operationQueue: syncOperationQueue
        )

        let stakingServiceFactory = StakingServiceFactory(
            chainRegisty: chainRegistry,
            storageFacade: storageFacade,
            eventCenter: eventCenter,
            operationQueue: syncOperationQueue,
            logger: logger
        )

        let localSubscriptionFactory = StakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManager(operationQueue: repositoryOperationQueue),
            logger: logger
        )

        let chainId = stakingOption.chainAsset.chain.chainId
        let eraValidatorService = try stakingServiceFactory.createEraValidatorService(for: chainId)

        guard let blockTimeService = try stakingServiceFactory.createBlockTimeService(
            for: chainId,
            consensus: consensus
        ) else {
            throw StakingSharedStateFactoryError.noBlockTimeService
        }

        let durationFactory = createStakingDuration(
            for: consensus,
            chain: stakingOption.chainAsset.chain,
            blockTimeService: blockTimeService
        )

        let rewardCalculatorService = try stakingServiceFactory.createRewardCalculatorService(
            for: stakingOption.chainAsset,
            stakingType: stakingOption.type,
            stakingLocalSubscriptionFactory: localSubscriptionFactory,
            stakingDurationFactory: durationFactory,
            validatorService: eraValidatorService
        )

        return RelaychainStakingSharedState(
            consensus: consensus,
            stakingOption: stakingOption,
            chainRegistry: chainRegistry,
            globalRemoteSubscriptionService: globalRemoteSubscriptionService,
            accountRemoteSubscriptionService: accountRemoteSubscriptionService,
            localSubscriptionFactory: localSubscriptionFactory,
            eraValidatorService: eraValidatorService,
            rewardCalculatorService: rewardCalculatorService,
            blockTimeService: blockTimeService,
            stakingDurationOperationFactory: durationFactory,
            operationQueue: syncOperationQueue,
            logger: logger
        )
    }

    func createParachain(
        for stakingOption: Multistaking.ChainAssetOption
    ) throws -> ParachainStakingSharedStateProtocol {
        let repositoryFactory = SubstrateRepositoryFactory()
        let repository = repositoryFactory.createChainStorageItemRepository()

        let stakingAccountService = ParachainStaking.AccountSubscriptionService(
            chainRegistry: chainRegistry,
            repository: repository,
            syncOperationManager: OperationManager(operationQueue: syncOperationQueue),
            repositoryOperationManager: OperationManager(operationQueue: repositoryOperationQueue),
            logger: logger
        )

        let stakingAssetService = ParachainStaking.StakingRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: repository,
            syncOperationManager: OperationManager(operationQueue: syncOperationQueue),
            repositoryOperationManager: OperationManager(operationQueue: repositoryOperationQueue),
            logger: logger
        )

        let localSubscriptionFactory = ParachainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManager(operationQueue: repositoryOperationQueue),
            logger: logger
        )

        let serviceFactory = ParachainStakingServiceFactory(
            stakingProviderFactory: localSubscriptionFactory,
            chainRegisty: chainRegistry,
            storageFacade: storageFacade,
            eventCenter: eventCenter,
            operationQueue: syncOperationQueue,
            logger: logger
        )

        let chainId = stakingOption.chainAsset.chain.chainId

        let collatorService = try serviceFactory.createSelectedCollatorsService(for: chainId)
        let blockTimeService = try serviceFactory.createBlockTimeService(for: chainId)
        let rewardService = try serviceFactory.createRewardCalculatorService(
            for: chainId,
            stakingType: stakingOption.type,
            assetPrecision: stakingOption.chainAsset.asset.decimalPrecision,
            collatorService: collatorService
        )

        let generalLocalSubscriptionFactory = GeneralStorageSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManager(operationQueue: repositoryOperationQueue),
            logger: logger
        )

        return ParachainStakingSharedState(
            stakingOption: stakingOption,
            chainRegistry: chainRegistry,
            globalRemoteSubscriptionService: stakingAssetService,
            accountRemoteSubscriptionService: stakingAccountService,
            collatorService: collatorService,
            rewardCalculationService: rewardService,
            blockTimeService: blockTimeService,
            stakingLocalSubscriptionFactory: localSubscriptionFactory,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            logger: logger
        )
    }
}
