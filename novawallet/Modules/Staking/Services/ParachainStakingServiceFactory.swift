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
    ) throws -> CollatorStakingRewardCalculatorServiceProtocol

    func createBlockTimeService(for chainId: ChainModel.Id) throws -> BlockTimeEstimationServiceProtocol
}

final class ParachainStakingServiceFactory: CollatorStakingServiceFactory, ParachainStakingServiceFactoryProtocol {
    let stakingProviderFactory: ParachainStakingLocalSubscriptionFactoryProtocol

    init(
        stakingProviderFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        chainRegisty: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.stakingProviderFactory = stakingProviderFactory

        super.init(
            chainRegisty: chainRegisty,
            storageFacade: storageFacade,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger
        )
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

    // swiftlint:disable:next function_body_length
    func createRewardCalculatorService(
        for chainId: ChainModel.Id,
        stakingType: StakingType,
        assetPrecision: Int16,
        collatorService: ParachainStakingCollatorServiceProtocol
    ) throws -> CollatorStakingRewardCalculatorServiceProtocol {
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
                eventCenter: eventCenter,
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
                eventCenter: eventCenter,
                logger: logger
            )
        default:
            throw CommonError.dataCorruption
        }
    }
}
