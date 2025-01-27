import Foundation

protocol MythosStakingSharedStateProtocol {
    var stakingOption: Multistaking.ChainAssetOption { get }
    var chainRegistry: ChainRegistryProtocol { get }
    var stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol { get }
    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol { get }
    var blockTimeService: BlockTimeEstimationServiceProtocol { get }

    var detailsSyncService: MythosStakingDetailsSyncServiceProtocol? { get }
    var claimableRewardsService: MythosStakingClaimableRewardsServiceProtocol? { get }

    var collatorService: MythosCollatorServiceProtocol { get }
    var rewardCalculatorService: CollatorStakingRewardCalculatorServiceProtocol { get }

    var preferredCollatorsProvider: PreferredValidatorsProviding { get }

    var logger: LoggerProtocol { get }

    var sharedOperation: SharedOperationProtocol? { get }

    func setup(for accountId: AccountId?)
    func throttle()
    func startSharedOperation() -> SharedOperationProtocol
}

final class MythosStakingSharedState {
    let stakingOption: Multistaking.ChainAssetOption
    let chainRegistry: ChainRegistryProtocol
    let collatorService: MythosCollatorServiceProtocol
    let rewardCalculatorService: CollatorStakingRewardCalculatorServiceProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let globalRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol
    let preferredCollatorsProvider: PreferredValidatorsProviding
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    weak var sharedOperation: SharedOperationProtocol?

    private var globalRemoteSubscription: UUID?

    private(set) var detailsSyncService: MythosStakingDetailsSyncServiceProtocol?
    private(set) var claimableRewardsService: MythosStakingClaimableRewardsServiceProtocol?

    init(
        stakingOption: Multistaking.ChainAssetOption,
        chainRegistry: ChainRegistryProtocol,
        collatorService: MythosCollatorServiceProtocol,
        rewardCalculatorService: CollatorStakingRewardCalculatorServiceProtocol,
        stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol,
        globalRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        preferredCollatorsProvider: PreferredValidatorsProviding,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.stakingOption = stakingOption
        self.chainRegistry = chainRegistry
        self.collatorService = collatorService
        self.rewardCalculatorService = rewardCalculatorService
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.globalRemoteSubscriptionService = globalRemoteSubscriptionService
        self.blockTimeService = blockTimeService
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.preferredCollatorsProvider = preferredCollatorsProvider
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension MythosStakingSharedState: MythosStakingSharedStateProtocol {
    func setup(for accountId: AccountId?) {
        let chainId = stakingOption.chainAsset.chain.chainId

        globalRemoteSubscription = globalRemoteSubscriptionService.attachToGlobalData(
            for: chainId,
            queue: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.logger.debug("Mythos staking global remote subscription succeeded")
            case let .failure(error):
                self?.logger.error("Mythos staking global remote subscription failed: \(error)")
            }
        }

        collatorService.setup()
        rewardCalculatorService.setup()
        blockTimeService.setup()

        if let accountId {
            detailsSyncService = MythosStakingDetailsSyncService(
                chainId: chainId,
                accountId: accountId,
                chainRegistry: chainRegistry,
                operationFactory: MythosCollatorOperationFactory(
                    chainRegistry: chainRegistry,
                    operationQueue: operationQueue,
                    timeout: JSONRPCTimeout.hour
                ),
                operationQueue: operationQueue
            )

            detailsSyncService?.setup()

            claimableRewardsService = MythosStakingClaimableRewardsService(
                chainId: chainId,
                accountId: accountId,
                chainRegistry: chainRegistry,
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                operationQueue: operationQueue
            )

            claimableRewardsService?.setup()
        }
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

        collatorService.throttle()
        rewardCalculatorService.throttle()
        blockTimeService.throttle()

        detailsSyncService?.throttle()
        detailsSyncService = nil

        claimableRewardsService?.throttle()
        claimableRewardsService = nil
    }

    func startSharedOperation() -> SharedOperationProtocol {
        let operation = SharedOperation()
        sharedOperation = operation
        return operation
    }
}
