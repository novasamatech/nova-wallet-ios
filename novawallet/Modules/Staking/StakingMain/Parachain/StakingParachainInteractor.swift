import Foundation
import Operation_iOS
import Foundation_iOS

final class StakingParachainInteractor: AnyProviderAutoCleaning, AnyCancellableCleaning {
    weak var presenter: StakingParachainInteractorOutputProtocol?

    var stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol {
        sharedState.stakingLocalSubscriptionFactory
    }

    var stakingRewardsLocalSubscriptionFactory: StakingRewardsLocalSubscriptionFactoryProtocol {
        sharedState.stakingRewardsLocalSubscriptionFactory
    }

    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol {
        sharedState.generalLocalSubscriptionFactory
    }

    var chainRegistry: ChainRegistryProtocol {
        sharedState.chainRegistry
    }

    let selectedWalletSettings: SelectedWalletSettings
    let sharedState: ParachainStakingSharedStateProtocol
    let scheduledRequestsFactory: ParaStkScheduledRequestsQueryFactoryProtocol
    let collatorsOperationFactory: ParaStkCollatorsOperationFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let networkInfoFactory: ParaStkNetworkInfoOperationFactoryProtocol
    let durationOperationFactory: ParaStkDurationOperationFactoryProtocol
    let yieldBoostSupport: ParaStkYieldBoostSupportProtocol
    let yieldBoostProviderFactory: ParaStkYieldBoostProviderFactoryProtocol
    let operationQueue: OperationQueue
    let eventCenter: EventCenterProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let logger: LoggerProtocol?

    var collatorsInfoCancellable: CancellableCall?
    var rewardCalculatorCancellable: CancellableCall?
    var networkInfoCancellable: CancellableCall?
    var delegationsCancellable: CancellableCall?
    var durationCancellable: CancellableCall?

    var priceProvider: StreamableProvider<PriceData>?
    var balanceProvider: StreamableProvider<AssetBalance>?
    var delegatorProvider: AnyDataProvider<ParachainStaking.DecodedDelegator>?
    var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    var roundInfoProvider: AnyDataProvider<ParachainStaking.DecodedRoundInfo>?
    var totalRewardProvider: AnySingleValueProvider<TotalRewardItem>?
    var scheduledRequestsProvider: StreamableProvider<ParachainStaking.MappedScheduledRequest>?
    var yieldBoostTasksProvider: AnySingleValueProvider<[ParaStkYieldBoostState.Task]>?

    var selectedAccount: MetaChainAccountResponse?
    var totalRewardInterval: StakingRewardFiltersInterval?
    var selectedChainAsset: ChainAsset { sharedState.stakingOption.chainAsset }

    init(
        selectedWalletSettings: SelectedWalletSettings,
        sharedState: ParachainStakingSharedStateProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        networkInfoFactory: ParaStkNetworkInfoOperationFactoryProtocol,
        durationOperationFactory: ParaStkDurationOperationFactoryProtocol,
        scheduledRequestsFactory: ParaStkScheduledRequestsQueryFactoryProtocol,
        collatorsOperationFactory: ParaStkCollatorsOperationFactoryProtocol,
        yieldBoostSupport: ParaStkYieldBoostSupportProtocol,
        yieldBoostProviderFactory: ParaStkYieldBoostProviderFactoryProtocol,
        eventCenter: EventCenterProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.sharedState = sharedState
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.networkInfoFactory = networkInfoFactory
        self.durationOperationFactory = durationOperationFactory
        self.scheduledRequestsFactory = scheduledRequestsFactory
        self.collatorsOperationFactory = collatorsOperationFactory
        self.yieldBoostSupport = yieldBoostSupport
        self.yieldBoostProviderFactory = yieldBoostProviderFactory
        self.eventCenter = eventCenter
        self.applicationHandler = applicationHandler
        self.operationQueue = operationQueue
        self.logger = logger
        self.currencyManager = currencyManager
    }

    deinit {
        clearCancellable()

        sharedState.throttle()
    }

    func clearCancellable() {
        clear(cancellable: &collatorsInfoCancellable)
        clear(cancellable: &rewardCalculatorCancellable)
        clear(cancellable: &networkInfoCancellable)
        clear(cancellable: &delegationsCancellable)
        clear(cancellable: &durationCancellable)
    }

    func setupSelectedAccount() {
        let chainAsset = sharedState.stakingOption.chainAsset

        selectedAccount = selectedWalletSettings.value?.fetchMetaChainAccount(
            for: chainAsset.chain.accountRequest()
        )
    }

    func setupSharedState() {
        let accountId = selectedAccount?.chainAccount.accountId
        sharedState.setup(for: accountId)
    }
}
