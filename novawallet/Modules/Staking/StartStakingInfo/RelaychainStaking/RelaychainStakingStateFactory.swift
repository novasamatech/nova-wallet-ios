import RobinHood
import Foundation

protocol RelaychainStakingStateFactoryProtocol {
    func createState() throws -> StakingSharedState
    var stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol { get }
}

final class RelaychainStakingStateFactory: RelaychainStakingStateFactoryProtocol {
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol

    private let stakingOption: Multistaking.ChainAssetOption
    private let chainRegistry: ChainRegistryProtocol
    private let storageFacade: StorageFacadeProtocol
    private let operationQueue: OperationQueue
    private let eventCenter: EventCenterProtocol
    private let logger: LoggerProtocol
    private let operationManager: OperationManagerProtocol

    init(
        stakingOption: Multistaking.ChainAssetOption,
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol,
        operationQueue: OperationQueue
    ) {
        self.stakingOption = stakingOption
        self.chainRegistry = chainRegistry
        self.storageFacade = storageFacade
        self.eventCenter = eventCenter
        let operationManager = OperationManager(operationQueue: operationQueue)

        stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )
        self.operationManager = operationManager
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
            chainRegisty: chainRegistry,
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
