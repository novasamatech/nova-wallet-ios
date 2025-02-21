import Foundation

protocol ParachainStakingSharedStateProtocol: AnyObject {
    var stakingOption: Multistaking.ChainAssetOption { get }
    var chainRegistry: ChainRegistryProtocol { get }
    var globalRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol { get }
    var accountRemoteSubscriptionService: StakingRemoteAccountSubscriptionServiceProtocol { get }
    var collatorService: ParachainStakingCollatorServiceInterfaces { get }
    var rewardCalculationService: CollatorStakingRewardCalculatorServiceProtocol { get }
    var blockTimeService: BlockTimeEstimationServiceProtocol { get }
    var stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol { get }
    var stakingRewardsLocalSubscriptionFactory: StakingRewardsLocalSubscriptionFactoryProtocol { get }
    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol { get }
    var preferredCollatorsProvider: PreferredValidatorsProviding { get }
    var logger: LoggerProtocol { get }

    var sharedOperation: SharedOperationProtocol? { get }

    func setup(for accountId: AccountId?)
    func throttle()
    func startSharedOperation() -> SharedOperationProtocol
}

final class ParachainStakingSharedState: ParachainStakingSharedStateProtocol {
    let stakingOption: Multistaking.ChainAssetOption
    let chainRegistry: ChainRegistryProtocol
    let globalRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol
    let accountRemoteSubscriptionService: StakingRemoteAccountSubscriptionServiceProtocol
    let collatorService: ParachainStakingCollatorServiceInterfaces
    let rewardCalculationService: CollatorStakingRewardCalculatorServiceProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let stakingRewardsLocalSubscriptionFactory: StakingRewardsLocalSubscriptionFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let preferredCollatorsProvider: PreferredValidatorsProviding
    let logger: LoggerProtocol

    private var globalRemoteSubscription: UUID?
    private var accountRemoteSubscription: AccountRemoteSubscriptionModel?

    weak var sharedOperation: SharedOperationProtocol?

    init(
        stakingOption: Multistaking.ChainAssetOption,
        chainRegistry: ChainRegistryProtocol,
        globalRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol,
        accountRemoteSubscriptionService: StakingRemoteAccountSubscriptionServiceProtocol,
        collatorService: ParachainStakingCollatorServiceInterfaces,
        rewardCalculationService: CollatorStakingRewardCalculatorServiceProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        stakingRewardsLocalSubscriptionFactory: StakingRewardsLocalSubscriptionFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        preferredCollatorsProvider: PreferredValidatorsProviding,
        logger: LoggerProtocol
    ) {
        self.stakingOption = stakingOption
        self.chainRegistry = chainRegistry
        self.globalRemoteSubscriptionService = globalRemoteSubscriptionService
        self.accountRemoteSubscriptionService = accountRemoteSubscriptionService
        self.collatorService = collatorService
        self.rewardCalculationService = rewardCalculationService
        self.blockTimeService = blockTimeService
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.stakingRewardsLocalSubscriptionFactory = stakingRewardsLocalSubscriptionFactory
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.preferredCollatorsProvider = preferredCollatorsProvider
        self.logger = logger
    }

    func setup(for accountId: AccountId?) {
        let chainId = stakingOption.chainAsset.chain.chainId

        globalRemoteSubscription = globalRemoteSubscriptionService.attachToGlobalData(
            for: chainId,
            queue: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.logger.debug("Parachain global remote subscription succeeded")
            case let .failure(error):
                self?.logger.error("Parachain global remote subscription failed: \(error)")
            }
        }

        if let accountId = accountId {
            let chainAccountId = ChainAccountId(chainId: chainId, accountId: accountId)
            let subscriptionId = accountRemoteSubscriptionService.attachToAccountData(
                for: chainAccountId,
                queue: .main
            ) { [weak self] result in
                switch result {
                case .success:
                    self?.logger.debug("Parachain account remote subscription succeeded")
                case let .failure(error):
                    self?.logger.error("Parachain account remote subscription failed: \(error)")
                }
            }

            if let subscriptionId {
                accountRemoteSubscription = AccountRemoteSubscriptionModel(
                    subscriptionId: subscriptionId,
                    chainAccountId: chainAccountId
                )
            }
        }

        collatorService.setup()
        rewardCalculationService.setup()
        blockTimeService.setup()
    }

    func throttle() {
        let chainId = stakingOption.chainAsset.chain.chainId

        if let globalRemoteSubscription = globalRemoteSubscription {
            globalRemoteSubscriptionService.detachFromGlobalData(
                for: globalRemoteSubscription,
                chainId: chainId,
                queue: nil,
                closure: nil
            )
        }

        if let accountRemoteSubscription {
            accountRemoteSubscriptionService.detachFromAccountData(
                for: accountRemoteSubscription.subscriptionId,
                chainAccountId: accountRemoteSubscription.chainAccountId,
                queue: nil,
                closure: nil
            )
        }

        collatorService.throttle()
        rewardCalculationService.throttle()
        blockTimeService.throttle()
    }

    func startSharedOperation() -> SharedOperationProtocol {
        let operation = SharedOperation()
        sharedOperation = operation
        return operation
    }
}
