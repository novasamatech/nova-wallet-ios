import Foundation
import Operation_iOS

protocol StakingServiceFactoryProtocol {
    func createEraValidatorService(
        for chainId: ChainModel.Id,
        localSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    ) throws -> EraValidatorServiceProtocol

    func createRewardCalculatorService(
        for chainAsset: ChainAsset,
        stakingType: StakingType,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        stakingDurationFactory: StakingDurationOperationFactoryProtocol,
        validatorService: EraValidatorServiceProtocol
    ) throws -> RewardCalculatorServiceProtocol

    func createTimeModel(for chainId: ChainModel.Id, consensus: ConsensusType) throws -> StakingTimeModel
}

final class StakingServiceFactory: StakingServiceFactoryProtocol {
    let chainRegisty: ChainRegistryProtocol
    let storageFacade: StorageFacadeProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

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

    func createEraValidatorService(
        for chainId: ChainModel.Id,
        localSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    ) throws -> EraValidatorServiceProtocol {
        let runtimeService = try chainRegisty.getRuntimeProviderOrError(for: chainId)
        let connection = try chainRegisty.getConnectionOrError(for: chainId)

        return EraValidatorService(
            chainId: chainId,
            storageFacade: storageFacade,
            runtimeCodingService: runtimeService,
            connection: connection,
            providerFactory: localSubscriptionFactory,
            operationQueue: operationQueue,
            eventCenter: eventCenter,
            logger: logger
        )
    }

    func createRewardCalculatorService(
        for chainAsset: ChainAsset,
        stakingType: StakingType,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        stakingDurationFactory: StakingDurationOperationFactoryProtocol,
        validatorService: EraValidatorServiceProtocol
    ) throws -> RewardCalculatorServiceProtocol {
        let chainId = chainAsset.chain.chainId

        let runtimeService = try chainRegisty.getRuntimeProviderOrError(for: chainId)
        let connection = try chainRegisty.getConnectionOrError(for: chainId)

        let rewardCalculatorFactory = RewardCalculatorEngineFactory(
            chainId: chainId,
            stakingType: stakingType,
            assetPrecision: chainAsset.assetDisplayInfo.assetPrecision
        )

        let rewardCalculatorParamsFactory = RewardCalculatorParamsServiceFactory(
            stakingType: stakingType,
            connection: connection,
            runtimeService: runtimeService,
            operationQueue: operationQueue
        )

        return RewardCalculatorService(
            chainId: chainId,
            rewardCalculatorFactory: rewardCalculatorFactory,
            rewardCalculatorParamsFactory: rewardCalculatorParamsFactory,
            eraValidatorsService: validatorService,
            operationManager: OperationManager(operationQueue: operationQueue),
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            runtimeCodingService: runtimeService,
            stakingDurationFactory: stakingDurationFactory,
            storageFacade: storageFacade,
            logger: logger
        )
    }

    func createTimeModel(for chainId: ChainModel.Id, consensus: ConsensusType) throws -> StakingTimeModel {
        switch consensus {
        case .babe:
            return .babe
        case .auraGeneral:
            let blockTimeService = try createBlockTimeService(for: chainId)
            return .auraGeneral(blockTimeService)
        case .auraAzero:
            let blockTimeService = try createBlockTimeService(for: chainId)
            return .azero(blockTimeService)
        }
    }

    private func createBlockTimeService(for chainId: ChainModel.Id) throws -> BlockTimeEstimationServiceProtocol {
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
