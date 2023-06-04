import UIKit
import RobinHood

final class StakingDashboardInteractor {
    weak var presenter: StakingDashboardInteractorOutputProtocol?

    let syncService: MultistakingSyncServiceProtocol
    let walletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let chainsStore: ChainsStoreProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol

    private var balanceProviders: [ChainAssetId: StreamableProvider<AssetBalance>] = [:]
    private var dashboardItemsProvider: StreamableProvider<Multistaking.DashboardItem>?

    private var priceProviders: [AssetModel.PriceId: StreamableProvider<PriceData>] = [:]
    private var priceMappings: [AssetModel.PriceId: ChainAssetId] = [:]

    private var stakableAssets: Set<ChainAsset> = []

    init(
        syncService: MultistakingSyncServiceProtocol,
        walletSettings: SelectedWalletSettings,
        chainsStore: ChainsStoreProtocol,
        eventCenter: EventCenterProtocol,
        stakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.syncService = syncService
        self.walletSettings = walletSettings
        self.eventCenter = eventCenter
        self.chainsStore = chainsStore
        self.stakingDashboardProviderFactory = stakingDashboardProviderFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.currencyManager = currencyManager
    }

    private func setupChainsStore() {
        chainsStore.delegate = self
        chainsStore.setup()
    }

    private func setupDashboardItemsSubscription() {
        dashboardItemsProvider = subscribeDashboardItems(for: walletSettings.value.metaId)
    }

    private func setupSyncStateSubscription() {
        syncService.subscribeSyncState(self, queue: .main) { [weak self] _, _ in
            // TODO: Notify
        }
    }

    private func resetBalanceSubscription() {
        balanceProviders = [:]
        updateBalanceSubscriptions(for: stakableAssets.allInsertChanges())
    }

    private func updateBalanceSubscriptions(for changes: [DataProviderChange<ChainAsset>]) {
        changes.forEach { change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                guard
                    balanceProviders[newItem.chainAssetId] == nil,
                    let account = walletSettings.value.fetch(for: newItem.chain.accountRequest()) else {
                    return
                }

                balanceProviders[newItem.chainAssetId] = subscribeToAssetBalanceProvider(
                    for: account.accountId,
                    chainId: newItem.chain.chainId,
                    assetId: newItem.asset.assetId
                )
            case let .delete(deletedIdentifier):
                balanceProviders = balanceProviders.filter { $0.key.chainId != deletedIdentifier }
            }
        }
    }

    private func resetPriceSubscription() {
        priceMappings = [:]
        priceProviders = [:]

        updatePriceSubscriptions(for: stakableAssets.allInsertChanges())
    }

    private func updatePriceSubscriptions(for changes: [DataProviderChange<ChainAsset>]) {
        changes.forEach { change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                guard
                    let priceId = newItem.asset.priceId,
                    priceProviders[priceId] == nil else {
                    return
                }

                priceMappings[priceId] = newItem.chainAssetId
                priceProviders[priceId] = subscribeToPrice(for: priceId, currency: selectedCurrency)
            case let .delete(deletedIdentifier):
                let priceIds = priceMappings
                    .filter { $0.value.stringValue == deletedIdentifier }
                    .map(\.key)

                priceIds.forEach { priceId in
                    priceMappings[priceId] = nil
                    priceProviders[priceId] = nil
                }
            }
        }
    }

    private func provideWallet() {
        // TODO: Notify new wallet
    }
}

extension StakingDashboardInteractor: StakingDashboardInteractorInputProtocol {
    func setup() {
        provideWallet()
        setupChainsStore()
        setupDashboardItemsSubscription()
        setupSyncStateSubscription()

        eventCenter.add(observer: self, dispatchIn: .main)
    }

    func retryBalancesSubscription() {
        resetBalanceSubscription()
    }

    func retryPricesSubscription() {
        resetPriceSubscription()
    }

    func retryDashboardSubscription() {
        dashboardItemsProvider = nil
        setupDashboardItemsSubscription()
    }
}

extension StakingDashboardInteractor: ChainsStoreDelegate {
    func didUpdateChainsStore(_ chainsStore: ChainsStoreProtocol) {
        let newChainAssets = chainsStore.getAllStakebleAssets()

        let changes = DataChangesDiffCalculator().calculateChanges(
            newItems: Array(newChainAssets),
            oldItems: Array(stakableAssets)
        )

        updateBalanceSubscriptions(for: changes)
        updatePriceSubscriptions(for: changes)
    }
}

extension StakingDashboardInteractor: StakingDashboardLocalStorageSubscriber, StakingDashboardLocalStorageHandler {
    func handleDashboardItems(
        _: Result<[DataProviderChange<Multistaking.DashboardItem>], Error>,
        walletId _: MetaAccountModel.Id
    ) {
        // TODO: Notify
    }
}

extension StakingDashboardInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result _: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        // TODO: Notify
    }
}

extension StakingDashboardInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result _: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        // TODO: Notify
    }
}

extension StakingDashboardInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        provideWallet()

        syncService.update(selectedMetaAccount: walletSettings.value)
        resetBalanceSubscription()
    }
}

extension StakingDashboardInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        resetPriceSubscription()
    }
}
