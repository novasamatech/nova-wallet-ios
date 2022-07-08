import Foundation
import RobinHood

protocol ParachainStakingServiceFactoryProtocol {
    func createSelectedCollatorsService(
        for chainId: ChainModel.Id
    ) throws -> ParachainStakingCollatorServiceProtocol

    func createRewardCalculatorService(
        for chainId: ChainModel.Id,
        stakingType: StakingType,
        assetPrecision: Int16,
        collatorService: ParachainStakingCollatorServiceProtocol
    ) throws -> ParaStakingRewardCalculatorServiceProtocol

    func createBlockTimeService(for chainId: ChainModel.Id) throws -> BlockTimeEstimationServiceProtocol
}

final class ParachainStakingServiceFactory: ParachainStakingServiceFactoryProtocol {
    let chainRegisty: ChainRegistryProtocol
    let storageFacade: StorageFacadeProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let stakingProviderFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let logger: LoggerProtocol

    init(
        stakingProviderFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        chainRegisty: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.stakingProviderFactory = stakingProviderFactory
        self.chainRegisty = chainRegisty
        self.storageFacade = storageFacade
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger
    }

    func createSelectedCollatorsService(
        for chainId: ChainModel.Id
    ) throws -> ParachainStakingCollatorServiceProtocol {
        guard let runtimeService = chainRegisty.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        guard let connection = chainRegisty.getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        return ParachainStakingCollatorService(
            chainId: chainId,
            storageFacade: storageFacade,
            runtimeCodingService: runtimeService,
            connection: connection,
            providerFactory: stakingProviderFactory,
            operationQueue: operationQueue,
            eventCenter: eventCenter,
            logger: logger
        )
    }

    func createRewardCalculatorService(
        for chainId: ChainModel.Id,
        stakingType: StakingType,
        assetPrecision: Int16,
        collatorService: ParachainStakingCollatorServiceProtocol
    ) throws -> ParaStakingRewardCalculatorServiceProtocol {
        guard let runtimeService = chainRegisty.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        guard let connection = chainRegisty.getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: storageFacade)

        switch stakingType {
        case .parachain:
            return ParaStakingRewardCalculatorService(
                chainId: chainId,
                collatorsService: collatorService,
                providerFactory: stakingProviderFactory,
                connection: connection,
                runtimeCodingService: runtimeService,
                repositoryFactory: repositoryFactory,
                operationQueue: operationQueue,
                assetPrecision: assetPrecision,
                logger: logger
            )
        case .turing:

            let repository = SubstrateRepositoryFactory(
                storageFacade: storageFacade
            ).createChainStorageItemRepository()

            let operationManager = OperationManager(operationQueue: operationQueue)

            let rewardsRemoteService = TuringStakingRemoteSubscriptionService(
                chainRegistry: chainRegisty,
                repository: repository,
                operationManager: operationManager,
                logger: logger
            )

            let rewardsLocalSubscriptionFactory = TuringStakingLocalSubscriptionFactory(
                chainRegistry: chainRegisty,
                storageFacade: storageFacade,
                operationManager: operationManager,
                logger: logger
            )

            return TuringRewardCalculatorService(
                chainId: chainId,
                rewardsRemoteSubscriptionService: rewardsRemoteService,
                rewardsLocalSubscriptionFactory: rewardsLocalSubscriptionFactory,
                collatorsService: collatorService,
                providerFactory: stakingProviderFactory,
                connection: connection,
                runtimeCodingService: runtimeService,
                repositoryFactory: repositoryFactory,
                operationQueue: operationQueue,
                assetPrecision: assetPrecision,
                logger: logger
            )
        default:
            throw CommonError.dataCorruption
        }
    }

    func createBlockTimeService(for chainId: ChainModel.Id) throws -> BlockTimeEstimationServiceProtocol {
        guard let runtimeService = chainRegisty.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        guard let connection = chainRegisty.getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: storageFacade)

        let repository = repositoryFactory.createChainStorageItemRepository()

        return BlockTimeEstimationService(
            chainId: chainId,
            connection: connection,
            runtimeService: runtimeService,
            repository: repository,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger
        )
    }
}
