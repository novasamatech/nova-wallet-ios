import Foundation
import RobinHood
import SubstrateSdk

protocol RelaychainStakingSharedStateProtocol: AnyObject {
    var consensus: ConsensusType { get }
    var stakingOption: Multistaking.ChainAssetOption { get }
    var chainRegistry: ChainRegistryProtocol { get }
    var globalRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol { get }
    var accountRemoteSubscriptionService: StakingAccountUpdatingServiceProtocol { get }
    var localSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol { get }
    var eraValidatorService: EraValidatorServiceProtocol { get }
    var rewardCalculatorService: RewardCalculatorServiceProtocol { get }
    var blockTimeService: BlockTimeEstimationServiceProtocol { get }
    var stakingDurationOperationFactory: StakingDurationOperationFactoryProtocol { get }

    func setup(for accountId: AccountId?) throws
    func throttle()

    func createNetworkInfoOperationFactory() -> NetworkStakingInfoOperationFactoryProtocol
    func createEraCountdownOperationFactory() -> EraCountdownOperationFactoryProtocol
}

final class RelaychainStakingSharedState: RelaychainStakingSharedStateProtocol {
    let consensus: ConsensusType
    let stakingOption: Multistaking.ChainAssetOption
    let chainRegistry: ChainRegistryProtocol
    let globalRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol
    let accountRemoteSubscriptionService: StakingAccountUpdatingServiceProtocol
    let localSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    let rewardCalculatorService: RewardCalculatorServiceProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let stakingDurationOperationFactory: StakingDurationOperationFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var globalSubscriptionId: UUID?

    var chain: ChainModel { stakingOption.chainAsset.chain }

    init(
        consensus: ConsensusType,
        stakingOption: Multistaking.ChainAssetOption,
        chainRegistry: ChainRegistryProtocol,
        globalRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol,
        accountRemoteSubscriptionService: StakingAccountUpdatingServiceProtocol,
        localSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        rewardCalculatorService: RewardCalculatorServiceProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        stakingDurationOperationFactory: StakingDurationOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.consensus = consensus
        self.stakingOption = stakingOption
        self.chainRegistry = chainRegistry
        self.globalRemoteSubscriptionService = globalRemoteSubscriptionService
        self.accountRemoteSubscriptionService = accountRemoteSubscriptionService
        self.localSubscriptionFactory = localSubscriptionFactory
        self.eraValidatorService = eraValidatorService
        self.rewardCalculatorService = rewardCalculatorService
        self.blockTimeService = blockTimeService
        self.stakingDurationOperationFactory = stakingDurationOperationFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }

    func setup(for accountId: AccountId?) throws {
        globalSubscriptionId = globalRemoteSubscriptionService.attachToGlobalData(
            for: chain.chainId,
            queue: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.logger.debug("Relaychain staking global data subscription succeeded")
            case let .failure(error):
                self?.logger.error("Relaychain staking global data subscription failed: \(error)")
            }
        }

        eraValidatorService.setup()
        rewardCalculatorService.setup()
        blockTimeService.setup()

        if let accountId = accountId {
            try accountRemoteSubscriptionService.setupSubscription(
                for: accountId,
                chainId: chain.chainId,
                chainFormat: chain.chainFormat
            )

            logger.debug("Relaychain staking account data subscription succeeded")
        } else {
            logger.debug("Relaychain staking global data subscription skipped")
        }
    }

    func throttle() {
        if let globalSubscriptionId = globalSubscriptionId {
            globalRemoteSubscriptionService.detachFromGlobalData(
                for: globalSubscriptionId,
                chainId: chain.chainId,
                queue: .main
            ) { [weak self] result in
                switch result {
                case .success:
                    self?.logger.debug("Relaychain staking global data unsubscribe succeeded")
                case let .failure(error):
                    self?.logger.error("Relaychain staking global data unsubscribe failed: \(error)")
                }
            }
        }

        eraValidatorService.throttle()
        rewardCalculatorService.throttle()
        blockTimeService.throttle()

        accountRemoteSubscriptionService.clearSubscription()
    }

    func createNetworkInfoOperationFactory() -> NetworkStakingInfoOperationFactoryProtocol {
        let votersInfoOperationFactory = VotersInfoOperationFactory(
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        return NetworkStakingInfoOperationFactory(
            durationFactory: stakingDurationOperationFactory,
            votersOperationFactory: votersInfoOperationFactory
        )
    }

    func createEraCountdownOperationFactory() -> EraCountdownOperationFactoryProtocol {
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        switch consensus {
        case .babe:
            return BabeEraOperationFactory(storageRequestFactory: storageRequestFactory)
        case .aura:
            return AuraEraOperationFactory(
                storageRequestFactory: storageRequestFactory,
                blockTimeService: blockTimeService,
                blockTimeOperationFactory: BlockTimeOperationFactory(chain: stakingOption.chainAsset.chain)
            )
        }
    }
}
