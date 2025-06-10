import Foundation
import Operation_iOS
import SubstrateSdk

protocol RelaychainStakingSharedStateProtocol: AnyObject {
    var consensus: ConsensusType { get }
    var stakingOption: Multistaking.ChainAssetOption { get }
    var globalRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol { get }
    var accountRemoteSubscriptionService: StakingAccountUpdatingServiceProtocol { get }
    var proxyLocalSubscriptionFactory: ProxyListLocalSubscriptionFactoryProtocol { get }
    var localSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol { get }
    var stakingRewardsLocalSubscriptionFactory: StakingRewardsLocalSubscriptionFactoryProtocol { get }
    var eraValidatorService: EraValidatorServiceProtocol { get }
    var rewardCalculatorService: RewardCalculatorServiceProtocol { get }
    var preferredValidatorsProvider: PreferredValidatorsProviding { get }

    func setup(for accountId: AccountId?) throws
    func throttle()

    func createNetworkInfoOperationFactory(
        for operationQueue: OperationQueue
    ) -> NetworkStakingInfoOperationFactoryProtocol

    func createEraCountdownOperationFactory(for operationQueue: OperationQueue) -> EraCountdownOperationFactoryProtocol
    func createStakingDurationOperationFactory() -> StakingDurationOperationFactoryProtocol
}

final class RelaychainStakingSharedState: RelaychainStakingSharedStateProtocol {
    let consensus: ConsensusType
    let timeModel: StakingTimeModel
    let stakingOption: Multistaking.ChainAssetOption
    let globalRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol
    let accountRemoteSubscriptionService: StakingAccountUpdatingServiceProtocol
    let localSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let stakingRewardsLocalSubscriptionFactory: StakingRewardsLocalSubscriptionFactoryProtocol
    let proxyLocalSubscriptionFactory: ProxyListLocalSubscriptionFactoryProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    let rewardCalculatorService: RewardCalculatorServiceProtocol
    let preferredValidatorsProvider: PreferredValidatorsProviding
    let logger: LoggerProtocol
    let proxyRemoteSubscriptionService: ProxyAccountUpdatingServiceProtocol?
    let multisigPendingOperationsSubscriptionService: MultisigPendingOperationsUpdatingServiceProtocol?

    private var globalSubscriptionId: UUID?

    private lazy var consensusDependingFactory = RelaychainConsensusStateDependingFactory()

    var chain: ChainModel { stakingOption.chainAsset.chain }

    init(
        consensus: ConsensusType,
        stakingOption: Multistaking.ChainAssetOption,
        globalRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol,
        accountRemoteSubscriptionService: StakingAccountUpdatingServiceProtocol,
        proxyRemoteSubscriptionService: ProxyAccountUpdatingServiceProtocol?,
        multisigPendingOperationsSubscriptionService: MultisigPendingOperationsUpdatingServiceProtocol?,
        localSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        stakingRewardsLocalSubscriptionFactory: StakingRewardsLocalSubscriptionFactoryProtocol,
        proxyLocalSubscriptionFactory: ProxyListLocalSubscriptionFactoryProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        rewardCalculatorService: RewardCalculatorServiceProtocol,
        preferredValidatorsProvider: PreferredValidatorsProviding,
        timeModel: StakingTimeModel,
        logger: LoggerProtocol
    ) {
        self.consensus = consensus
        self.stakingOption = stakingOption
        self.globalRemoteSubscriptionService = globalRemoteSubscriptionService
        self.accountRemoteSubscriptionService = accountRemoteSubscriptionService
        self.proxyRemoteSubscriptionService = proxyRemoteSubscriptionService
        self.multisigPendingOperationsSubscriptionService = multisigPendingOperationsSubscriptionService
        self.localSubscriptionFactory = localSubscriptionFactory
        self.stakingRewardsLocalSubscriptionFactory = stakingRewardsLocalSubscriptionFactory
        self.proxyLocalSubscriptionFactory = proxyLocalSubscriptionFactory
        self.eraValidatorService = eraValidatorService
        self.rewardCalculatorService = rewardCalculatorService
        self.preferredValidatorsProvider = preferredValidatorsProvider
        self.timeModel = timeModel
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
        timeModel.blockTimeService?.setup()

        if let accountId = accountId {
            try accountRemoteSubscriptionService.setupSubscription(
                for: accountId,
                chainId: chain.chainId,
                chainFormat: chain.chainFormat
            )
            if chain.hasProxy {
                try proxyRemoteSubscriptionService?.setupSubscription(
                    for: accountId,
                    chainId: chain.chainId
                )
            }
            if chain.hasMultisig {
                try multisigPendingOperationsSubscriptionService?.setupSubscription(
                    for: accountId,
                    callHashes: <#T##Set<CallHash>#>,
                    chainId: chain.chainId
                )
            }

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
        timeModel.blockTimeService?.throttle()

        accountRemoteSubscriptionService.clearSubscription()
        proxyRemoteSubscriptionService?.clearSubscription()
    }

    func createNetworkInfoOperationFactory(
        for operationQueue: OperationQueue
    ) -> NetworkStakingInfoOperationFactoryProtocol {
        let durationFactory = consensusDependingFactory.createStakingDurationOperationFactory(
            for: stakingOption.chainAsset.chain,
            timeModel: timeModel
        )

        return consensusDependingFactory.createNetworkInfoOperationFactory(
            for: stakingOption.chainAsset.chain,
            durationFactory: durationFactory,
            operationQueue: operationQueue
        )
    }

    func createEraCountdownOperationFactory(
        for operationQueue: OperationQueue
    ) -> EraCountdownOperationFactoryProtocol {
        consensusDependingFactory.createEraCountdownOperationFactory(
            for: stakingOption.chainAsset.chain,
            timeModel: timeModel,
            operationQueue: operationQueue
        )
    }

    func createStakingDurationOperationFactory() -> StakingDurationOperationFactoryProtocol {
        consensusDependingFactory.createStakingDurationOperationFactory(
            for: stakingOption.chainAsset.chain,
            timeModel: timeModel
        )
    }
}
