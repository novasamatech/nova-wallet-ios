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

    func createTimeModel(for chainId: ChainModel.Id, consensus: RelayStkConsensusType) throws -> StakingTimeModel
}

final class StakingServiceFactory: StakingServiceFactoryProtocol {
    let chainRegisty: ChainRegistryProtocol
    let storageFacade: StorageFacadeProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let blockTimeServiceFactory: BlockTimeEstimationServiceFactoryProtocol

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

        blockTimeServiceFactory = BlockTimeEstimationServiceFactory(
            chainRegisty: chainRegisty,
            storageFacade: storageFacade,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger
        )
    }

    func createEraValidatorService(
        for chainId: ChainModel.Id,
        localSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    ) throws -> EraValidatorServiceProtocol {
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
        guard let runtimeService = chainRegisty.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        guard let connection = chainRegisty.getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

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
            stakingDurationFactory: stakingDurationFactory,
            storageFacade: storageFacade,
            logger: logger
        )
    }

    func createTimeModel(for chainId: ChainModel.Id, consensus: RelayStkConsensusType) throws -> StakingTimeModel {
        let timelineChain = try chainRegisty.getTimelineChainOrError(for: chainId)

        switch consensus {
        case .babe:
            return .babe(timelineChain)
        case .auraGeneral:
            let blockTimeService = try blockTimeServiceFactory.createService(for: timelineChain.chainId)
            return .auraGeneral(timelineChain, blockTimeService)
        case .auraAzero:
            let blockTimeService = try blockTimeServiceFactory.createService(for: timelineChain.chainId)
            return .azero(timelineChain, blockTimeService)
        }
    }
}
