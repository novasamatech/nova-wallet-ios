import Foundation

protocol RelaychainStartStakingStateProtocol: AnyObject {
    var stakingType: StakingType? { get }
    var chainAsset: ChainAsset { get }

    var relaychainGlobalSubscriptionService: StakingRemoteSubscriptionServiceProtocol { get }
    var blockTimeService: BlockTimeEstimationServiceProtocol { get }
    var durationOperationFactory: StakingDurationOperationFactoryProtocol { get }

    var relaychainAccountSubscriptionService: StakingAccountUpdatingServiceProtocol { get }
    var relaychainLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol { get }
    var eraValidatorService: EraValidatorServiceProtocol { get }
    var relaychainRewardCalculatorService: RewardCalculatorServiceProtocol { get }

    var npRemoteSubstriptionService: StakingRemoteSubscriptionServiceProtocol? { get }
    var npAccountSubscriptionServiceFactory: NominationPoolsAccountUpdatingFactoryProtocol? { get }
    var npLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol? { get }
    var activePoolsService: EraNominationPoolsServiceProtocol? { get }

    func setup(for accountId: AccountId?) throws
    func throttle()
    func supportsPoolStaking() -> Bool
}

final class RelaychainStartStakingState: RelaychainStartStakingStateProtocol {
    let stakingType: StakingType?
    let chainAsset: ChainAsset

    let relaychainGlobalSubscriptionService: StakingRemoteSubscriptionServiceProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let durationOperationFactory: StakingDurationOperationFactoryProtocol

    let relaychainAccountSubscriptionService: StakingAccountUpdatingServiceProtocol
    let relaychainLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    let relaychainRewardCalculatorService: RewardCalculatorServiceProtocol

    let chainRegistry: ChainRegistryProtocol
    let substrateRepositoryFactory: SubstrateRepositoryFactoryProtocol
    let logger: LoggerProtocol

    let npRemoteSubstriptionService: StakingRemoteSubscriptionServiceProtocol?
    let npAccountSubscriptionServiceFactory: NominationPoolsAccountUpdatingFactoryProtocol?
    let npLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol?
    let activePoolsService: EraNominationPoolsServiceProtocol?

    private var relaychainGlobalSubscriptionId: UUID?
    private var npGlobalSubscriptionId: UUID?
    private var npAccountService: NominationPoolsAccountUpdatingService?

    init(
        stakingType: StakingType?,
        chainAsset: ChainAsset,
        chainRegistry: ChainRegistryProtocol,
        relaychainGlobalSubscriptionService: StakingRemoteSubscriptionServiceProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        durationOperationFactory: StakingDurationOperationFactoryProtocol,
        relaychainAccountSubscriptionService: StakingAccountUpdatingServiceProtocol,
        relaychainLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        relaychainRewardCalculatorService: RewardCalculatorServiceProtocol,
        npRemoteSubstriptionService: StakingRemoteSubscriptionServiceProtocol?,
        npAccountSubscriptionServiceFactory: NominationPoolsAccountUpdatingFactoryProtocol?,
        npLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol?,
        activePoolsService: EraNominationPoolsServiceProtocol?,
        substrateRepositoryFactory: SubstrateRepositoryFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.stakingType = stakingType
        self.chainAsset = chainAsset
        self.chainRegistry = chainRegistry
        self.relaychainGlobalSubscriptionService = relaychainGlobalSubscriptionService
        self.blockTimeService = blockTimeService
        self.durationOperationFactory = durationOperationFactory
        self.relaychainAccountSubscriptionService = relaychainAccountSubscriptionService
        self.relaychainLocalSubscriptionFactory = relaychainLocalSubscriptionFactory
        self.eraValidatorService = eraValidatorService
        self.relaychainRewardCalculatorService = relaychainRewardCalculatorService
        self.npRemoteSubstriptionService = npRemoteSubstriptionService
        self.npAccountSubscriptionServiceFactory = npAccountSubscriptionServiceFactory
        self.npLocalSubscriptionFactory = npLocalSubscriptionFactory
        self.activePoolsService = activePoolsService
        self.substrateRepositoryFactory = substrateRepositoryFactory
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
        blockTimeService.setup()

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
        blockTimeService.throttle()

        relaychainAccountSubscriptionService.clearSubscription()

        activePoolsService?.throttle()

        npAccountService?.throttle()
        npAccountService = nil
    }

    func supportsPoolStaking() -> Bool {
        npRemoteSubstriptionService != nil
    }
}
