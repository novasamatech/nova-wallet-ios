import UIKit
import Operation_iOS
import SubstrateSdk
import SoraFoundation

final class MythosStakingDetailsInteractor: AnyProviderAutoCleaning {
    weak var presenter: MythosStakingDetailsInteractorOutputProtocol?

    var chainRegistry: ChainRegistryProtocol {
        sharedState.chainRegistry
    }

    var stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol {
        sharedState.stakingLocalSubscriptionFactory
    }

    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol {
        sharedState.generalLocalSubscriptionFactory
    }

    let selectedAccount: MetaChainAccountResponse
    let sharedState: MythosStakingSharedStateProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
    let eventCenter: EventCenterProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var frozenBalanceStore: MythosStakingFrozenBalanceStore?

    var priceProvider: StreamableProvider<PriceData>?
    var balanceProvider: StreamableProvider<AssetBalance>?
    var releaseQueueProvider: AnyDataProvider<MythosStakingPallet.DecodedReleaseQueue>?
    var totalRewardProvider: AnySingleValueProvider<TotalRewardItem>?
    var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?

    var totalRewardInterval: StakingRewardFiltersInterval?

    let blockTimeReqStore = CancellableCallStore()
    let collatorReqStore = CancellableCallStore()

    var chain: ChainModel {
        chainAsset.chain
    }

    var chainAsset: ChainAsset {
        sharedState.stakingOption.chainAsset
    }

    var selectedAccountId: AccountId {
        selectedAccount.chainAccount.accountId
    }

    init(
        selectedAccount: MetaChainAccountResponse,
        sharedState: MythosStakingSharedStateProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        blockTimeOperationFactory: BlockTimeOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.sharedState = sharedState
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.blockTimeOperationFactory = blockTimeOperationFactory
        self.eventCenter = eventCenter
        self.applicationHandler = applicationHandler
        self.operationQueue = operationQueue
        self.logger = logger
        self.currencyManager = currencyManager
    }

    deinit {
        clearRequests()
        sharedState.throttle()
    }
}

extension MythosStakingDetailsInteractor {
    func setupState() {
        sharedState.setup(for: selectedAccountId)

        presenter?.didReceiveChainAsset(chainAsset)
        presenter?.didReceiveAccount(selectedAccount)
    }

    func clearRequests() {
        blockTimeReqStore.cancel()
        collatorReqStore.cancel()
    }

    func makeBalanceSubscription() {
        clear(streamableProvider: &balanceProvider)
        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccountId,
            chainId: chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    func makeBlockNumberProvider() {
        clear(dataProvider: &blockNumberProvider)

        blockNumberProvider = subscribeToBlockNumber(for: chain.chainId)
    }

    func makePriceSubscription() {
        clear(streamableProvider: &priceProvider)

        guard let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    func makeStakingDetailsSubscription() {
        sharedState.detailsSyncService?.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            self?.presenter?.didReceiveStakingDetails(newState)
        }
    }

    func makeClaimableRewardsSubscription() {
        sharedState.claimableRewardsService?.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            self?.presenter?.didReceiveClaimableRewards(newState)
        }
    }

    func makeReleaseQueueSubscription() {
        releaseQueueProvider = subscribeToReleaseQueue(
            for: chain.chainId,
            accountId: selectedAccountId
        )
    }

    func setupFrozenStore() {
        if frozenBalanceStore == nil {
            frozenBalanceStore = MythosStakingFrozenBalanceStore(
                accountId: selectedAccountId,
                chainAssetId: chainAsset.chainAssetId,
                walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
                logger: logger
            )

            frozenBalanceStore?.setup()
        }

        frozenBalanceStore?.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            self?.presenter?.didReceiveFrozenBalance(newState)
        }
    }

    func provideElectedCollators() {
        collatorReqStore.cancel()

        let operation = sharedState.collatorService.fetchInfoOperation()

        execute(
            operation: operation,
            inOperationQueue: operationQueue,
            backingCallIn: collatorReqStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(collators):
                self?.presenter?.didReceiveElectedCollators(collators)
            case let .failure(error):
                self?.logger.error("Elected collators fetch failed: \(error)")
            }
        }
    }

    func provideBlockTime() {
        do {
            blockTimeReqStore.cancel()

            let runtimeService = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)
            let wrapper = blockTimeOperationFactory.createBlockTimeOperation(
                from: runtimeService,
                blockTimeEstimationService: sharedState.blockTimeService
            )

            executeCancellable(
                wrapper: wrapper,
                inOperationQueue: operationQueue,
                backingCallIn: blockTimeReqStore,
                runningCallbackIn: .main
            ) { [weak self] result in
                switch result {
                case let .success(blockTime):
                    self?.presenter?.didReceiveBlockTime(blockTime)
                case let .failure(error):
                    self?.logger.error("Block time request failed: \(error)")
                }
            }
        } catch {
            logger.error("Block time error: \(error)")
        }
    }

    func makeTotalRewardSubscription() {
        // TODO: Implment total reward subscription
    }
}

extension MythosStakingDetailsInteractor: MythosStakingDetailsInteractorInputProtocol {
    func setup() {
        setupState()

        makeBalanceSubscription()
        makePriceSubscription()
        setupFrozenStore()
        makeStakingDetailsSubscription()
        makeClaimableRewardsSubscription()
        makeReleaseQueueSubscription()
        makeBlockNumberProvider()
        makeTotalRewardSubscription()

        provideElectedCollators()

        eventCenter.add(observer: self, dispatchIn: .main)

        applicationHandler.delegate = self
    }

    func update(totalRewardFilter: StakingRewardFiltersPeriod) {
        totalRewardInterval = totalRewardFilter.interval
        makeTotalRewardSubscription()
    }
}

extension MythosStakingDetailsInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId: ChainModel.Id
    ) {
        guard chain.chainId == chainId else {
            return
        }

        switch result {
        case let .success(blockNumber):
            if let blockNumber {
                provideBlockTime()

                presenter?.didReceiveBlockNumber(blockNumber)
            }
        case let .failure(error):
            logger.error("Block subscription error: \(error)")
        }
    }
}

extension MythosStakingDetailsInteractor: MythosStakingLocalStorageSubscriber,
    MythosStakingLocalStorageHandler {
    func handleReleaseQueue(
        result: Result<MythosStakingPallet.ReleaseQueue?, Error>,
        chainId: ChainModel.Id,
        accountId: AccountId
    ) {
        guard
            chainId == chain.chainId,
            accountId == selectedAccountId else {
            return
        }

        switch result {
        case let .success(releaseQueue):
            presenter?.didReceiveReleaseQueue(releaseQueue)
        case let .failure(error):
            logger.error("Balance subscription error: \(error)")
        }
    }
}

extension MythosStakingDetailsInteractor: WalletLocalStorageSubscriber,
    WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard
            chainId == chain.chainId,
            assetId == chainAsset.asset.assetId,
            accountId == selectedAccountId else {
            return
        }

        switch result {
        case let .success(balance):
            presenter?.didReceiveAssetBalance(balance)
        case let .failure(error):
            logger.error("Balance subscription error: \(error)")
        }
    }
}

extension MythosStakingDetailsInteractor: EventVisitorProtocol {
    func processEraStakersInfoChanged(event: EraStakersInfoChanged) {
        guard event.chainId == chain.chainId else {
            return
        }

        provideElectedCollators()
    }
}

extension MythosStakingDetailsInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        priceProvider?.refresh()
    }
}

extension MythosStakingDetailsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        if chainAsset.asset.priceId == priceId {
            switch result {
            case let .success(priceData):
                presenter?.didReceivePrice(priceData)
            case let .failure(error):
                logger.error("Price subscription error: \(error)")
            }
        }
    }
}

extension MythosStakingDetailsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        makePriceSubscription()
    }
}
