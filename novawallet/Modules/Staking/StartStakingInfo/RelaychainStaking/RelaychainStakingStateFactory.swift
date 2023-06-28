import RobinHood
import Foundation

protocol RelaychainStakingStateFactoryProtocol {
    func createState() throws -> StakingSharedState
}

final class RelaychainStakingStateFactory: RelaychainStakingStateFactoryProtocol {
    private let stakingOption: Multistaking.ChainAssetOption
    private let chainRegisty: ChainRegistryProtocol
    private let storageFacade: StorageFacadeProtocol
    private let operationQueue: OperationQueue
    private let eventCenter: EventCenterProtocol
    private let logger: LoggerProtocol
    private let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    lazy var operationManager = OperationManager(operationQueue: operationQueue)

    init(
        stakingOption: Multistaking.ChainAssetOption,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        chainRegisty: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared,
        eventCenter: EventCenterProtocol = EventCenter.shared,
        logger: LoggerProtocol = Logger.shared,
        operationQueue: OperationQueue
    ) {
        self.stakingOption = stakingOption
        self.chainRegisty = chainRegisty
        self.storageFacade = storageFacade
        self.eventCenter = eventCenter
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.logger = logger
        self.operationQueue = operationQueue
    }

    func createState() throws -> StakingSharedState {
        let consensus: ConsensusType

        switch stakingOption.type {
        case .relaychain, .nominationPools:
            consensus = .babe
        case .auraRelaychain, .azero:
            consensus = .aura
        case .parachain, .turing, .unsupported:
            throw RelaychainStakingStateFactoryError.noSupportedOptions
        }

        let chainAsset = stakingOption.chainAsset
        let stakingServiceFactory = StakingServiceFactory(
            chainRegisty: chainRegisty,
            storageFacade: storageFacade,
            eventCenter: eventCenter,
            operationQueue: operationQueue,
            logger: logger
        )

        let blockTimeService = try stakingServiceFactory.createBlockTimeService(
            for: chainAsset.chain.chainId,
            consensus: consensus
        )

        let eraValidatorService = try stakingServiceFactory.createEraValidatorService(for: chainAsset.chain.chainId)
        let stakingDurationFactory = try createStakingDurationOperationFactory(
            consensus: consensus,
            blockTimeService: blockTimeService,
            for: chainAsset.chain
        )
        let rewardCalculatorService = try stakingServiceFactory.createRewardCalculatorService(
            for: chainAsset,
            stakingType: chainAsset.asset.stakings?.first ?? .unsupported,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            stakingDurationFactory: stakingDurationFactory,
            validatorService: eraValidatorService
        )

        return StakingSharedState(
            consensus: consensus,
            stakingOption: stakingOption,
            eraValidatorService: eraValidatorService,
            rewardCalculationService: rewardCalculatorService,
            blockTimeService: blockTimeService,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory
        )
    }

    func createStakingDurationOperationFactory(
        consensus: ConsensusType,
        blockTimeService: BlockTimeEstimationServiceProtocol?,
        for chain: ChainModel
    ) throws -> StakingDurationOperationFactoryProtocol {
        switch consensus {
        case .babe:
            return BabeStakingDurationFactory()
        case .aura:
            guard let blockTimeService = blockTimeService else {
                throw StakingSharedStateError.missingBlockTimeService
            }
            return AuraStakingDurationFactory(
                blockTimeService: blockTimeService,
                blockTimeOperationFactory: BlockTimeOperationFactory(chain: chain)
            )
        }
    }
}

enum RelaychainStakingStateFactoryError: Error {
    case noSupportedOptions
}
