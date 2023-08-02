import Foundation

protocol RelaychainStartStakingStateProtocol: AnyObject {
    var stakingType: StakingType? { get }
    var consensus: ConsensusType { get }
    var chainAsset: ChainAsset { get }

    var relaychainGlobalSubscriptionService: StakingRemoteSubscriptionServiceProtocol { get }
    var timeModel: StakingTimeModel { get }
    var relaychainAccountSubscriptionService: StakingAccountUpdatingServiceProtocol { get }
    var relaychainLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol { get }
    var eraValidatorService: EraValidatorServiceProtocol { get }
    var relaychainRewardCalculatorService: RewardCalculatorServiceProtocol { get }

    var npRemoteSubstriptionService: NominationPoolsRemoteSubscriptionServiceProtocol? { get }
    var npAccountSubscriptionServiceFactory: NominationPoolsAccountUpdatingFactoryProtocol? { get }
    var npLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol? { get }
    var activePoolsService: EraNominationPoolsServiceProtocol? { get }

    func setup(for accountId: AccountId?) throws
    func throttle()
    func supportsPoolStaking() -> Bool

    func createNetworkInfoOperationFactory(
        for operationQueue: OperationQueue
    ) -> NetworkStakingInfoOperationFactoryProtocol

    func createEraCountdownOperationFactory(
        for operationQueue: OperationQueue
    ) -> EraCountdownOperationFactoryProtocol

    func createStakingDurationOperationFactory() -> StakingDurationOperationFactoryProtocol
}

final class RelaychainStartStakingState: RelaychainStartStakingStateProtocol {
    let stakingType: StakingType?
    let consensus: ConsensusType
    let chainAsset: ChainAsset

    let relaychainGlobalSubscriptionService: StakingRemoteSubscriptionServiceProtocol
    let relaychainAccountSubscriptionService: StakingAccountUpdatingServiceProtocol
    let timeModel: StakingTimeModel
    let relaychainLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    let relaychainRewardCalculatorService: RewardCalculatorServiceProtocol
    let logger: LoggerProtocol

    let npRemoteSubstriptionService: NominationPoolsRemoteSubscriptionServiceProtocol?
    let npAccountSubscriptionServiceFactory: NominationPoolsAccountUpdatingFactoryProtocol?
    let npLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol?
    let activePoolsService: EraNominationPoolsServiceProtocol?

    private var relaychainGlobalSubscriptionId: UUID?
    private var npGlobalSubscriptionId: UUID?
    private var npAccountService: NominationPoolsAccountUpdatingService?

    private lazy var consensusDependingFactory = RelaychainConsensusStateDependingFactory()

    init(
        stakingType: StakingType?,
        consensus: ConsensusType,
        chainAsset: ChainAsset,
        relaychainGlobalSubscriptionService: StakingRemoteSubscriptionServiceProtocol,
        relaychainAccountSubscriptionService: StakingAccountUpdatingServiceProtocol,
        timeModel: StakingTimeModel,
        relaychainLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        relaychainRewardCalculatorService: RewardCalculatorServiceProtocol,
        npRemoteSubstriptionService: NominationPoolsRemoteSubscriptionServiceProtocol?,
        npAccountSubscriptionServiceFactory: NominationPoolsAccountUpdatingFactoryProtocol?,
        npLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol?,
        activePoolsService: EraNominationPoolsServiceProtocol?,
        logger: LoggerProtocol
    ) {
        self.stakingType = stakingType
        self.chainAsset = chainAsset
        self.consensus = consensus
        self.relaychainGlobalSubscriptionService = relaychainGlobalSubscriptionService
        self.timeModel = timeModel
        self.relaychainAccountSubscriptionService = relaychainAccountSubscriptionService
        self.relaychainLocalSubscriptionFactory = relaychainLocalSubscriptionFactory
        self.eraValidatorService = eraValidatorService
        self.relaychainRewardCalculatorService = relaychainRewardCalculatorService
        self.npRemoteSubstriptionService = npRemoteSubstriptionService
        self.npAccountSubscriptionServiceFactory = npAccountSubscriptionServiceFactory
        self.npLocalSubscriptionFactory = npLocalSubscriptionFactory
        self.activePoolsService = activePoolsService
        self.logger = logger
    }

    func setup(for accountId: AccountId?) throws {
        let chainId = chainAsset.chain.chainId

        relaychainGlobalSubscriptionId = relaychainGlobalSubscriptionService.attachToGlobalData(
            for: chainId,
            queue: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.logger.debug("Relaychain global subscription succeeded")
            case let .failure(error):
                self?.logger.error("Relaychain global subscription failed: \(error)")
            }
        }

        eraValidatorService.setup()
        relaychainRewardCalculatorService.setup()
        timeModel.blockTimeService?.setup()

        npGlobalSubscriptionId = npRemoteSubstriptionService?.attachToGlobalData(
            for: chainId,
            queue: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.logger.debug("Nomination pools global subscription succeeded")
            case let .failure(error):
                self?.logger.error("Nomination pools global subscription failed: \(error)")
            }
        }

        activePoolsService?.setup()

        if let accountId = accountId {
            try relaychainAccountSubscriptionService.setupSubscription(
                for: accountId,
                chainId: chainId,
                chainFormat: chainAsset.chain.chainFormat
            )

            npAccountService = try npAccountSubscriptionServiceFactory?.create(
                for: accountId,
                chainAsset: chainAsset
            )

            npAccountService?.setup()
        }
    }

    func throttle() {
        let chainId = chainAsset.chain.chainId

        if let relaychainGlobalSubscriptionId = relaychainGlobalSubscriptionId {
            relaychainGlobalSubscriptionService.detachFromGlobalData(
                for: relaychainGlobalSubscriptionId,
                chainId: chainId,
                queue: .main
            ) { [weak self] result in
                switch result {
                case .success:
                    self?.logger.debug("Relaychain global data unsubscribe succeeded")
                case let .failure(error):
                    self?.logger.error("Relaychain global data unsubscribe failed: \(error)")
                }
            }

            self.relaychainGlobalSubscriptionId = nil
        }

        if let npGlobalSubscriptionId = npGlobalSubscriptionId {
            npRemoteSubstriptionService?.detachFromGlobalData(
                for: npGlobalSubscriptionId,
                chainId: chainId,
                queue: .main
            ) { [weak self] result in
                switch result {
                case .success:
                    self?.logger.debug("Nomination pools global data unsubscribe succeeded")
                case let .failure(error):
                    self?.logger.error("Nomination pools global data unsubscribe failed: \(error)")
                }
            }

            self.npGlobalSubscriptionId = nil
        }

        eraValidatorService.throttle()
        relaychainRewardCalculatorService.throttle()
        timeModel.blockTimeService?.throttle()

        relaychainAccountSubscriptionService.clearSubscription()

        activePoolsService?.throttle()

        npAccountService?.throttle()
        npAccountService = nil
    }

    func supportsPoolStaking() -> Bool {
        npRemoteSubstriptionService != nil
    }

    func createNetworkInfoOperationFactory(
        for operationQueue: OperationQueue
    ) -> NetworkStakingInfoOperationFactoryProtocol {
        let durationFactory = consensusDependingFactory.createStakingDurationOperationFactory(
            for: chainAsset.chain,
            timeModel: timeModel
        )

        return consensusDependingFactory.createNetworkInfoOperationFactory(
            for: durationFactory,
            operationQueue: operationQueue
        )
    }

    func createEraCountdownOperationFactory(
        for operationQueue: OperationQueue
    ) -> EraCountdownOperationFactoryProtocol {
        consensusDependingFactory.createEraCountdownOperationFactory(
            for: chainAsset.chain,
            timeModel: timeModel,
            operationQueue: operationQueue
        )
    }

    func createStakingDurationOperationFactory() -> StakingDurationOperationFactoryProtocol {
        consensusDependingFactory.createStakingDurationOperationFactory(
            for: chainAsset.chain,
            timeModel: timeModel
        )
    }
}
