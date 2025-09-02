import Foundation
import SubstrateSdk
import Operation_iOS

protocol MythosStakingSharedStateProtocol {
    var stakingOption: Multistaking.ChainAssetOption { get }
    var chainRegistry: ChainRegistryProtocol { get }
    var stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol { get }
    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol { get }
    var stakingRewardsLocalSubscriptionFactory: StakingRewardsLocalSubscriptionFactoryProtocol { get }
    var blockTimeService: BlockTimeEstimationServiceProtocol { get }

    var detailsSyncService: MythosStakingDetailsSyncServiceProtocol? { get }
    var claimableRewardsService: MythosStakingClaimableRewardsServiceProtocol? { get }
    var collatorIdentitiesSyncService: MythosStakingIdentitiesSyncServiceProtocol? { get }

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
    let accountRemoteSubscriptionService: StakingRemoteAccountSubscriptionServiceProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol
    let stakingRewardsLocalSubscriptionFactory: StakingRewardsLocalSubscriptionFactoryProtocol
    let preferredCollatorsProvider: PreferredValidatorsProviding
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    weak var sharedOperation: SharedOperationProtocol?

    private var globalRemoteSubscription: UUID?
    private var accountRemoteSubscription: AccountRemoteSubscriptionModel?

    private(set) var stakeSyncService: MythosStakingStakeSyncService?
    private(set) var detailsSyncService: MythosStakingDetailsSyncServiceProtocol?
    private(set) var claimableRewardsService: MythosStakingClaimableRewardsServiceProtocol?
    private(set) var collatorIdentitiesSyncService: MythosStakingIdentitiesSyncServiceProtocol?

    init(
        stakingOption: Multistaking.ChainAssetOption,
        chainRegistry: ChainRegistryProtocol,
        collatorService: MythosCollatorServiceProtocol,
        rewardCalculatorService: CollatorStakingRewardCalculatorServiceProtocol,
        stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol,
        stakingRewardsLocalSubscriptionFactory: StakingRewardsLocalSubscriptionFactoryProtocol,
        globalRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol,
        accountRemoteSubscriptionService: StakingRemoteAccountSubscriptionServiceProtocol,
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
        self.stakingRewardsLocalSubscriptionFactory = stakingRewardsLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.globalRemoteSubscriptionService = globalRemoteSubscriptionService
        self.accountRemoteSubscriptionService = accountRemoteSubscriptionService
        self.blockTimeService = blockTimeService
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.preferredCollatorsProvider = preferredCollatorsProvider
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension MythosStakingSharedState {
    func setupStakeSyncService(for accountId: AccountId) -> MythosStakingStakeSyncService {
        let stakeSyncService = MythosStakingStakeSyncService(
            accountId: accountId,
            chainId: stakingOption.chainAsset.chain.chainId,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        self.stakeSyncService = stakeSyncService

        stakeSyncService.setup()

        return stakeSyncService
    }

    func setupStakingDetailsSyncService(
        for accountId: AccountId,
        syncService: MythosStakingStakeSyncService
    ) {
        let chainId = stakingOption.chainAsset.chain.chainId

        detailsSyncService = MythosStakingDetailsSyncService(
            chainId: chainId,
            accountId: accountId,
            chainRegistry: chainRegistry,
            syncService: syncService,
            operationFactory: MythosCollatorOperationFactory(
                chainRegistry: chainRegistry,
                operationQueue: operationQueue,
                timeout: JSONRPCTimeout.hour
            ),
            operationQueue: operationQueue
        )

        detailsSyncService?.setup()
    }

    func setupClaimableRewardsService(
        for accountId: AccountId,
        syncService: MythosStakingStakeSyncService
    ) {
        let chainId = stakingOption.chainAsset.chain.chainId

        claimableRewardsService = MythosStakingClaimableRewardsService(
            chainId: chainId,
            accountId: accountId,
            chainRegistry: chainRegistry,
            syncService: syncService,
            operationQueue: operationQueue
        )

        claimableRewardsService?.setup()
    }

    func setupCollatorIdentitiesService(for accountId: AccountId) {
        let chain = stakingOption.chainAsset.chain

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let identitiesOperationFactory = IdentityOperationFactory(
            requestFactory: requestFactory
        )

        let identitiesProxyFactory = IdentityProxyFactory(
            originChain: chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: identitiesOperationFactory
        )

        collatorIdentitiesSyncService = MythosStakingIdentitiesSyncService(
            chainId: chain.chainId,
            accountId: accountId,
            chainRegistry: chainRegistry,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            operationFactory: identitiesProxyFactory,
            operationQueue: operationQueue
        )

        collatorIdentitiesSyncService?.setup()
    }

    func setupGlobalRemoteSubscriptionService(for chainId: ChainModel.Id) {
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
    }

    func throttleGlobalRemoteSubscription(for chainId: ChainModel.Id) {
        if let globalRemoteSubscription {
            globalRemoteSubscriptionService.detachFromGlobalData(
                for: globalRemoteSubscription,
                chainId: chainId,
                queue: nil,
                closure: nil
            )
        }
    }

    func setupAccountRemoteSubscriptionService(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) {
        let chainAccountId = ChainAccountId(chainId: chainId, accountId: accountId)
        let subscriptionId = accountRemoteSubscriptionService.attachToAccountData(
            for: chainAccountId,
            queue: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.logger.debug("Mythos staking account remote subscription succeeded")
            case let .failure(error):
                self?.logger.error("Mythos staking account remote subscription failed: \(error)")
            }
        }

        if let subscriptionId {
            accountRemoteSubscription = AccountRemoteSubscriptionModel(
                subscriptionId: subscriptionId,
                chainAccountId: chainAccountId
            )
        }
    }

    func throttleAccountRemoteSubscription() {
        if let accountRemoteSubscription {
            accountRemoteSubscriptionService.detachFromAccountData(
                for: accountRemoteSubscription.subscriptionId,
                chainAccountId: accountRemoteSubscription.chainAccountId,
                queue: nil,
                closure: nil
            )
        }
    }
}

extension MythosStakingSharedState: MythosStakingSharedStateProtocol {
    func setup(for accountId: AccountId?) {
        let chainId = stakingOption.chainAsset.chain.chainId

        setupGlobalRemoteSubscriptionService(for: chainId)

        collatorService.setup()
        rewardCalculatorService.setup()
        blockTimeService.setup()

        if let accountId {
            setupAccountRemoteSubscriptionService(for: chainId, accountId: accountId)

            let stakeSyncService = setupStakeSyncService(for: accountId)

            setupStakingDetailsSyncService(
                for: accountId,
                syncService: stakeSyncService
            )

            setupClaimableRewardsService(
                for: accountId,
                syncService: stakeSyncService
            )

            setupCollatorIdentitiesService(for: accountId)
        }
    }

    func throttle() {
        let chainId = stakingOption.chainAsset.chain.chainId

        throttleGlobalRemoteSubscription(for: chainId)

        throttleAccountRemoteSubscription()

        collatorService.throttle()
        rewardCalculatorService.throttle()
        blockTimeService.throttle()

        stakeSyncService?.throttle()
        stakeSyncService = nil

        detailsSyncService?.throttle()
        detailsSyncService = nil

        claimableRewardsService?.throttle()
        claimableRewardsService = nil

        collatorIdentitiesSyncService?.throttle()
        collatorIdentitiesSyncService = nil
    }

    func startSharedOperation() -> SharedOperationProtocol {
        let operation = SharedOperation()
        sharedOperation = operation
        return operation
    }
}
