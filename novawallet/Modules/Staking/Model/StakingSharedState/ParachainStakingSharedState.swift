import Foundation

protocol ParachainStakingSharedStateProtocol: AnyObject {
    var stakingOption: Multistaking.ChainAssetOption { get }
    var chainRegistry: ChainRegistryProtocol { get }
    var globalRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol { get }
    var accountRemoteSubscriptionService: ParachainStakingAccountSubscriptionServiceProtocol { get }
    var collatorService: ParachainStakingCollatorServiceProtocol { get }
    var rewardCalculationService: ParaStakingRewardCalculatorServiceProtocol { get }
    var blockTimeService: BlockTimeEstimationServiceProtocol { get }
    var stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol { get }
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
    let accountRemoteSubscriptionService: ParachainStakingAccountSubscriptionServiceProtocol
    let collatorService: ParachainStakingCollatorServiceProtocol
    let rewardCalculationService: ParaStakingRewardCalculatorServiceProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let preferredCollatorsProvider: PreferredValidatorsProviding
    let logger: LoggerProtocol

    private var globalRemoteSubscription: UUID?
    private var accountRemoteSubscription: UUID?

    weak var sharedOperation: SharedOperationProtocol?

    init(
        stakingOption: Multistaking.ChainAssetOption,
        chainRegistry: ChainRegistryProtocol,
        globalRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol,
        accountRemoteSubscriptionService: ParachainStakingAccountSubscriptionServiceProtocol,
        collatorService: ParachainStakingCollatorServiceProtocol,
        rewardCalculationService: ParaStakingRewardCalculatorServiceProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
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
            accountRemoteSubscription = accountRemoteSubscriptionService.attachToAccountData(
                for: chainId,
                accountId: accountId,
                queue: .main
            ) { [weak self] result in
                switch result {
                case .success:
                    self?.logger.debug("Parachain account remote subscription succeeded")
                case let .failure(error):
                    self?.logger.error("Parachain account remote subscription failed: \(error)")
                }
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

        if let accountRemoteSubscription = accountRemoteSubscription {
            globalRemoteSubscriptionService.detachFromGlobalData(
                for: accountRemoteSubscription,
                chainId: chainId,
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
