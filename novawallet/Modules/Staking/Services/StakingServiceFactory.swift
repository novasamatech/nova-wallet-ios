import Foundation
import RobinHood

protocol StakingServiceFactoryProtocol {
    func createEraValidatorService(for chainId: ChainModel.Id) throws -> EraValidatorServiceProtocol
    func createRewardCalculatorService(
        for chainId: ChainModel.Id,
        stakingType: StakingType,
        stakingDurationFactory: StakingDurationOperationFactoryProtocol,
        assetPrecision: Int16,
        validatorService: EraValidatorServiceProtocol
    ) throws -> RewardCalculatorServiceProtocol

    func createBlockTimeService(
        for chainId: ChainModel.Id,
        consensus: ConsensusType
    ) throws -> BlockTimeEstimationServiceProtocol?
}

final class StakingServiceFactory: StakingServiceFactoryProtocol {
    let chainRegisty: ChainRegistryProtocol
    let storageFacade: StorageFacadeProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private lazy var substrateDataProviderFactory = SubstrateDataProviderFactory(
        facade: storageFacade,
        operationManager: OperationManager(operationQueue: operationQueue)
    )

    init(
        chainRegisty: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegisty = chainRegisty
        self.storageFacade = storageFacade
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger
    }

    func createEraValidatorService(for chainId: ChainModel.Id) throws -> EraValidatorServiceProtocol {
        guard let runtimeService = chainRegisty.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        guard let connection = chainRegisty.getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        return EraValidatorService(
            chainId: chainId,
            storageFacade: storageFacade,
            runtimeCodingService: runtimeService,
            connection: connection,
            providerFactory: substrateDataProviderFactory,
            operationManager: OperationManager(operationQueue: operationQueue),
            eventCenter: eventCenter,
            logger: logger
        )
    }

    func createRewardCalculatorService(
        for chainId: ChainModel.Id,
        stakingType: StakingType,
        stakingDurationFactory: StakingDurationOperationFactoryProtocol,
        assetPrecision: Int16,
        validatorService: EraValidatorServiceProtocol
    ) throws -> RewardCalculatorServiceProtocol {
        guard let runtimeService = chainRegisty.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        let rewardCalculatorFactory = RewardCalculatorEngineFactory(
            chainId: chainId,
            stakingType: stakingType,
            assetPrecision: assetPrecision
        )

        return RewardCalculatorService(
            chainId: chainId,
            rewardCalculatorFactory: rewardCalculatorFactory,
            eraValidatorsService: validatorService,
            operationManager: OperationManager(operationQueue: operationQueue),
            providerFactory: substrateDataProviderFactory,
            runtimeCodingService: runtimeService,
            stakingDurationFactory: stakingDurationFactory,
            storageFacade: storageFacade,
            logger: logger
        )
    }

    func createBlockTimeService(
        for chainId: ChainModel.Id,
        consensus: ConsensusType
    ) throws -> BlockTimeEstimationServiceProtocol? {
        switch consensus {
        case .babe:
            return nil
        case .aura:
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
}
