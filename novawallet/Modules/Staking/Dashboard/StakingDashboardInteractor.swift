import UIKit
import Operation_iOS
import Foundation_iOS

final class StakingDashboardInteractor {
    weak var presenter: StakingDashboardInteractorOutputProtocol?

    let syncServiceFactory: MultistakingSyncServiceFactoryProtocol
    let walletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let chainsStore: ChainsStoreProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol
    let applicationHandler: ApplicationHandlerProtocol
    let stateObserver: Observable<StakingDashboardModel>
    let walletNotificationService: WalletNotificationServiceProtocol

    private var syncService: MultistakingSyncServiceProtocol?
    private var modelBuilder: StakingDashboardBuilderProtocol?

    private var balanceProviders: [ChainAssetId: StreamableProvider<AssetBalance>] = [:]
    private var dashboardItemsProvider: StreamableProvider<Multistaking.DashboardItem>?

    private var priceMappings: [AssetModel.PriceId: Set<String>] = [:]
    private var priceProviders: [AssetModel.PriceId: StreamableProvider<PriceData>] = [:]

    private var stakableAssets: Set<ChainAsset> = []

    init(
        syncServiceFactory: MultistakingSyncServiceFactoryProtocol,
        walletSettings: SelectedWalletSettings,
        chainsStore: ChainsStoreProtocol,
        eventCenter: EventCenterProtocol,
        stakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stateObserver: Observable<StakingDashboardModel>,
        applicationHandler: ApplicationHandlerProtocol,
        walletNotificationService: WalletNotificationServiceProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.syncServiceFactory = syncServiceFactory
        self.walletSettings = walletSettings
        self.eventCenter = eventCenter
        self.chainsStore = chainsStore
        self.stakingDashboardProviderFactory = stakingDashboardProviderFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.applicationHandler = applicationHandler
        self.stateObserver = stateObserver
        self.walletNotificationService = walletNotificationService
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
        syncService?.setup()

        syncService?.subscribeSyncState(self, queue: .main) { [weak self] _, state in
            self?.modelBuilder?.applySync(state: state)
        }
    }

    private func resetBalanceSubscription() {
        balanceProviders = [:]
        updateBalanceSubscriptions(for: stakableAssets.allInsertChanges())
    }

    private func resetDashboardItemsSubscription() {
        dashboardItemsProvider = nil
        setupDashboardItemsSubscription()
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
        priceProviders = [:]
        priceMappings = [:]

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

                var newAssets = priceMappings[priceId] ?? Set()
                newAssets.insert(newItem.identifier)

                priceMappings[priceId] = newAssets
                priceProviders[priceId] = subscribeToPrice(for: priceId, currency: selectedCurrency)
            case let .delete(deletedIdentifier):
                guard let priceIdKeyValue = priceMappings.first(where: { $0.value.contains(deletedIdentifier) }) else {
                    return
                }

                let priceId = priceIdKeyValue.key

                var newAssets = priceIdKeyValue.value
                newAssets.remove(deletedIdentifier)

                if newAssets.isEmpty {
                    priceProviders[priceId] = nil
                    priceMappings[priceId] = nil
                } else {
                    priceMappings[priceId] = newAssets
                }
            }
        }
    }

    private func provideWallet() {
        guard let wallet = walletSettings.value else {
            return
        }

        presenter?.didReceive(wallet: wallet)

        modelBuilder?.applyWallet(model: wallet)
    }
}

extension StakingDashboardInteractor: StakingDashboardInteractorInputProtocol {
    func setup() {
        modelBuilder = StakingDashboardBuilder { [weak self] result in
            self?.presenter?.didReceive(result: result)
            self?.stateObserver.state = result.model
        }

        syncService = syncServiceFactory.createService(for: SelectedWalletSettings.shared.value)

        provideWallet()
        setupChainsStore()
        setupDashboardItemsSubscription()
        setupSyncStateSubscription()

        eventCenter.add(observer: self, dispatchIn: .main)
        applicationHandler.delegate = self

        walletNotificationService.hasUpdatesObservable.addObserver(
            with: self,
            sendStateOnSubscription: true
        ) { [weak self] _, newState in
            self?.presenter?.didReceiveWalletsState(hasUpdates: newState)
        }
    }

    func retryBalancesSubscription() {
        resetBalanceSubscription()
    }

    func retryPricesSubscription() {
        resetPriceSubscription()
    }

    func retryDashboardSubscription() {
        resetDashboardItemsSubscription()
    }

    func refresh() {
        syncService?.refreshOffchain()
    }
}

extension StakingDashboardInteractor: ChainsStoreDelegate {
    func didUpdateChainsStore(_ chainsStore: ChainsStoreProtocol) {
        let newChainAssets = chainsStore.getAllStakebleAssets(filter: { $0.syncMode.enabled() })

        modelBuilder?.applyAssets(models: newChainAssets)

        let changes = DataChangesDiffCalculator().calculateChanges(
            newItems: Array(newChainAssets),
            oldItems: Array(stakableAssets)
        )

        stakableAssets = newChainAssets

        updateBalanceSubscriptions(for: changes)
        updatePriceSubscriptions(for: changes)
    }
}

extension StakingDashboardInteractor: StakingDashboardLocalStorageSubscriber, StakingDashboardLocalStorageHandler {
    func handleDashboardItems(
        _ result: Result<[DataProviderChange<Multistaking.DashboardItem>], Error>,
        walletId _: MetaAccountModel.Id
    ) {
        switch result {
        case let .success(changes):
            modelBuilder?.applyDashboardItem(changes: changes)
        case let .failure(error):
            presenter?.didReceive(error: .stakingsFetchFailed(error))
        }
    }
}

extension StakingDashboardInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        let chainAssetId = ChainAssetId(chainId: chainId, assetId: assetId)

        switch result {
        case let .success(balance):
            modelBuilder?.applyBalance(model: balance, chainAssetId: chainAssetId)
        case let .failure(error):
            presenter?.didReceive(error: .balanceFetchFailed(chainAssetId, error))
        }
    }
}

extension StakingDashboardInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            modelBuilder?.applyPrice(model: priceData, priceId: priceId)
        case let .failure(error):
            presenter?.didReceive(error: .priceFetchFailed(priceId, error))
        }
    }
}

extension StakingDashboardInteractor: EventVisitorProtocol {
    func processSelectedWalletChanged(event _: SelectedWalletSwitched) {
        guard let wallet = walletSettings.value else {
            return
        }

        provideWallet()

        syncService?.update(selectedMetaAccount: wallet)
        resetDashboardItemsSubscription()
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

extension StakingDashboardInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        syncService?.setup()
    }

    func didReceiveDidEnterBackground(notification _: Notification) {
        syncService?.throttle()
    }
}
