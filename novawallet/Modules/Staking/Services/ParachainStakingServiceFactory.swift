import Foundation
import Operation_iOS

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
        let runtimeService = try chainRegisty.getRuntimeProviderOrError(for: chainId)
        let connection = try chainRegisty.getConnectionOrError(for: chainId)

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

    // swiftlint:disable:next function_body_length
    func createRewardCalculatorService(
        for chainId: ChainModel.Id,
        stakingType: StakingType,
        assetPrecision: Int16,
        collatorService: ParachainStakingCollatorServiceProtocol
    ) throws -> ParaStakingRewardCalculatorServiceProtocol {
        let runtimeService = try chainRegisty.getRuntimeProviderOrError(for: chainId)
        let connection = try chainRegisty.getConnectionOrError(for: chainId)

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
                syncOperationManager: operationManager,
                repositoryOperationManager: operationManager,
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
        let runtimeService = try chainRegisty.getRuntimeProviderOrError(for: chainId)
        let connection = try chainRegisty.getConnectionOrError(for: chainId)

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
