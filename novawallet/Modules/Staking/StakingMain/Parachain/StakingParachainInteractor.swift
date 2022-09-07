import Foundation
import RobinHood
import SoraFoundation

final class StakingParachainInteractor: AnyProviderAutoCleaning, AnyCancellableCleaning {
    weak var presenter: StakingParachainInteractorOutputProtocol?

    var stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol {
        sharedState.stakingLocalSubscriptionFactory
    }

    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol {
        sharedState.generalLocalSubscriptionFactory
    }

    let selectedWalletSettings: SelectedWalletSettings
    let sharedState: ParachainStakingSharedState
    let chainRegistry: ChainRegistryProtocol
    let stakingAssetSubscriptionService: StakingRemoteSubscriptionServiceProtocol
    let stakingAccountSubscriptionService: ParachainStakingAccountSubscriptionServiceProtocol
    let scheduledRequestsFactory: ParaStkScheduledRequestsQueryFactoryProtocol
    let collatorsOperationFactory: ParaStkCollatorsOperationFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingServiceFactory: ParachainStakingServiceFactoryProtocol
    let networkInfoFactory: ParaStkNetworkInfoOperationFactoryProtocol
    let durationOperationFactory: ParaStkDurationOperationFactoryProtocol
    let yieldBoostSupport: ParaStkYieldBoostSupportProtocol
    let yieldBoostProviderFactory: ParaStkYieldBoostProviderFactoryProtocol
    let operationQueue: OperationQueue
    let eventCenter: EventCenterProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let logger: LoggerProtocol?

    var chainSubscriptionId: UUID?
    var accountSubscriptionId: UUID?
    var collatorsInfoCancellable: CancellableCall?
    var rewardCalculatorCancellable: CancellableCall?
    var networkInfoCancellable: CancellableCall?
    var delegationsCancellable: CancellableCall?
    var durationCancellable: CancellableCall?

    var priceProvider: AnySingleValueProvider<PriceData>?
    var balanceProvider: StreamableProvider<AssetBalance>?
    var delegatorProvider: AnyDataProvider<ParachainStaking.DecodedDelegator>?
    var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    var roundInfoProvider: AnyDataProvider<ParachainStaking.DecodedRoundInfo>?
    var totalRewardProvider: AnySingleValueProvider<TotalRewardItem>?
    var scheduledRequestsProvider: StreamableProvider<ParachainStaking.MappedScheduledRequest>?
    var yieldBoostTasksProvider: AnySingleValueProvider<[ParaStkYieldBoostState.Task]>?

    var selectedAccount: MetaChainAccountResponse?
    var selectedChainAsset: ChainAsset?

    init(
        selectedWalletSettings: SelectedWalletSettings,
        sharedState: ParachainStakingSharedState,
        chainRegistry: ChainRegistryProtocol,
        stakingAssetSubscriptionService: StakingRemoteSubscriptionServiceProtocol,
        stakingAccountSubscriptionService: ParachainStakingAccountSubscriptionServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingServiceFactory: ParachainStakingServiceFactoryProtocol,
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
        self.chainRegistry = chainRegistry
        self.stakingAssetSubscriptionService = stakingAssetSubscriptionService
        self.stakingAccountSubscriptionService = stakingAccountSubscriptionService
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.stakingServiceFactory = stakingServiceFactory
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
        if let selectedChainAsset = selectedChainAsset {
            clearChainRemoteSubscription(for: selectedChainAsset.chain.chainId)
        }

        clearAccountRemoteSubscription()
        clearCancellable()

        sharedState.collatorService?.throttle()
        sharedState.rewardCalculationService?.throttle()
        sharedState.blockTimeService?.throttle()
    }

    func clearCancellable() {
        clear(cancellable: &collatorsInfoCancellable)
        clear(cancellable: &rewardCalculatorCancellable)
        clear(cancellable: &networkInfoCancellable)
        clear(cancellable: &delegationsCancellable)
        clear(cancellable: &durationCancellable)
    }

    func setupSelectedAccountAndChainAsset() {
        guard let chainAsset = sharedState.settings.value else {
            return
        }

        selectedAccount = selectedWalletSettings.value?.fetchMetaChainAccount(
            for: chainAsset.chain.accountRequest()
        )

        selectedChainAsset = chainAsset
    }

    func createInitialServices() {
        guard let chainAsset = sharedState.settings.value else {
            return
        }

        do {
            let chainId = chainAsset.chain.chainId
            let collatorsService = try stakingServiceFactory.createSelectedCollatorsService(
                for: chainId
            )

            let rewardCalculatorService = try stakingServiceFactory.createRewardCalculatorService(
                for: chainId,
                stakingType: StakingType(rawType: chainAsset.asset.staking),
                assetPrecision: Int16(chainAsset.asset.precision),
                collatorService: collatorsService
            )

            let blockTimeService = try stakingServiceFactory.createBlockTimeService(
                for: chainId
            )

            sharedState.replaceCollatorService(collatorsService)
            sharedState.replaceRewardCalculatorService(rewardCalculatorService)
            sharedState.replaceBlockTimeService(blockTimeService)
        } catch {
            logger?.error("Couldn't create shared state")
            presenter?.didReceiveError(error)
        }
    }

    func continueSetup() {
        setupSelectedAccountAndChainAsset()
        setupChainRemoteSubscription()
        setupAccountRemoteSubscription()

        sharedState.collatorService?.setup()
        sharedState.rewardCalculationService?.setup()
        sharedState.blockTimeService?.setup()

        provideSelectedChainAsset()
        provideSelectedAccount()

        guard
            let collatorService = sharedState.collatorService,
            let rewardCalculationService = sharedState.rewardCalculationService,
            let blockTimeService = sharedState.blockTimeService else {
            return
        }

        performBlockNumberSubscription()
        performRoundInfoSubscription()
        performPriceSubscription()
        performAssetBalanceSubscription()
        performDelegatorSubscription()
        performTotalRewardSubscription()
        performYieldBoostTasksSubscription()

        provideRewardCalculator(from: rewardCalculationService)
        provideSelectedCollatorsInfo(from: collatorService)
        provideNetworkInfo(for: collatorService, rewardService: rewardCalculationService)
        provideDurationInfo(for: blockTimeService)

        eventCenter.add(observer: self, dispatchIn: .main)

        applicationHandler.delegate = self
    }

    func updateAfterSelectedAccountChange() {
        clearAccountRemoteSubscription()
        clear(streamableProvider: &balanceProvider)
        clear(dataProvider: &delegatorProvider)
        clear(singleValueProvider: &totalRewardProvider)
        clear(singleValueProvider: &yieldBoostTasksProvider)

        guard let selectedChain = selectedChainAsset?.chain else {
            return
        }

        selectedAccount = selectedWalletSettings.value?.fetchMetaChainAccount(
            for: selectedChain.accountRequest()
        )

        provideSelectedAccount()

        setupAccountRemoteSubscription()

        performAssetBalanceSubscription()
        performDelegatorSubscription()
        performTotalRewardSubscription()
        performYieldBoostTasksSubscription()
    }

    func updateOnAssetBalanceReceive() {
        yieldBoostTasksProvider?.refresh()
    }
}
