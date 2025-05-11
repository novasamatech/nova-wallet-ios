import Foundation
import Operation_iOS
import SubstrateSdk
import Keystore_iOS
import BigInt

final class AssetListInteractor: AssetListBaseInteractor {
    var presenter: AssetListInteractorOutputProtocol?

    var modelBuilder: AssetListBuilder? {
        get {
            baseBuilder as? AssetListBuilder
        }

        set {
            baseBuilder = newValue
        }
    }

    let nftLocalSubscriptionFactory: NftLocalSubscriptionFactoryProtocol
    let eventCenter: EventCenterProtocol
    let settingsManager: SettingsManagerProtocol
    let assetListModelObservable: AssetListModelObservable

    private var nftSubscription: StreamableProvider<NftModel>?
    private var nftChainIds: Set<ChainModel.Id>?

    private var assetLocksSubscriptions: [AccountId: StreamableProvider<AssetLock>] = [:]
    private var locks: [ChainAssetId: [AssetLock]] = [:]

    private var assetHoldsSubscriptions: [AccountId: StreamableProvider<AssetHold>] = [:]
    private var holds: [ChainAssetId: [AssetHold]] = [:]

    init(
        selectedWalletSettings: SelectedWalletSettings,
        chainRegistry: ChainRegistryProtocol,
        assetListModelObservable: AssetListModelObservable,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        nftLocalSubscriptionFactory: NftLocalSubscriptionFactoryProtocol,
        externalBalancesSubscriptionFactory: ExternalBalanceLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        eventCenter: EventCenterProtocol,
        settingsManager: SettingsManagerProtocol,
        currencyManager: CurrencyManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.nftLocalSubscriptionFactory = nftLocalSubscriptionFactory
        self.assetListModelObservable = assetListModelObservable
        self.eventCenter = eventCenter
        self.settingsManager = settingsManager
        super.init(
            selectedWalletSettings: selectedWalletSettings,
            chainRegistry: chainRegistry,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            externalBalancesSubscriptionFactory: externalBalancesSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            currencyManager: currencyManager,
            logger: logger
        )
    }

    override func resetWallet() {
        clearNftSubscription()
        clearLocksSubscription()
        clearHoldsSubscription()

        super.resetWallet()
    }

    override func didResetWallet(
        allChanges: [DataProviderChange<ChainModel>],
        enabledChainChanges: [DataProviderChange<ChainModel>]
    ) {
        super.didResetWallet(allChanges: allChanges, enabledChainChanges: enabledChainChanges)

        setupNftSubscription(from: Array(availableChains.values))
        updateLocksSubscription(from: enabledChainChanges)
        updateHoldsSubscription(from: enabledChainChanges)
    }

    private func provideWalletInfo() {
        guard let wallet = selectedWalletSettings.value else {
            return
        }

        presenter?.didReceive(walletId: wallet.identifier)
    }

    private func clearLocksSubscription() {
        assetLocksSubscriptions.values.forEach { $0.removeObserver(self) }
        assetLocksSubscriptions = [:]
        locks = [:]
    }

    private func clearHoldsSubscription() {
        assetHoldsSubscriptions.values.forEach { $0.removeObserver(self) }
        assetHoldsSubscriptions = [:]
        holds = [:]
    }

    private func provideHidesZeroBalances() {
        let value = settingsManager.hidesZeroBalances
        presenter?.didReceive(hidesZeroBalances: value)
    }

    private func clearNftSubscription() {
        nftSubscription?.removeObserver(self)
        nftSubscription = nil

        nftChainIds = nil
    }

    override func applyChanges(
        allChanges: [DataProviderChange<ChainModel>],
        enabledChainChanges: [DataProviderChange<ChainModel>]
    ) {
        super.applyChanges(allChanges: allChanges, enabledChainChanges: enabledChainChanges)

        setupNftSubscription(from: Array(availableChains.values))
        updateLocksSubscription(from: enabledChainChanges)
        updateHoldsSubscription(from: enabledChainChanges)
    }

    private func setupNftSubscription(from allChains: [ChainModel]) {
        let nftChains = allChains.filter { !$0.nftSources.isEmpty }

        let newNftChainIds = Set(nftChains.map(\.chainId))

        guard !newNftChainIds.isEmpty, newNftChainIds != nftChainIds else {
            return
        }

        clearNftSubscription()

        modelBuilder?.applyNftReset()

        nftChainIds = newNftChainIds

        nftSubscription = subscribeToNftProvider(for: selectedWalletSettings.value, chains: nftChains)
        nftSubscription?.refresh()
    }

    override func setup() {
        provideWalletInfo()

        presenter?.didReceiveAssetListGroupStyle(settingsManager.assetListGroupStyle)
        modelBuilder = .init { [weak self] result in
            self?.presenter?.didReceive(result: result)

            self?.assetListModelObservable.state = .init(value: .init(model: result.model))
        }

        provideHidesZeroBalances()

        subscribeChains()

        eventCenter.add(observer: self, dispatchIn: .main)
    }

    private func updateLocksSubscription(from changes: [DataProviderChange<ChainModel>]) {
        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        assetLocksSubscriptions = changes.reduce(
            intitial: assetLocksSubscriptions,
            selectedMetaAccount: selectedMetaAccount
        ) { [weak self] in
            self?.subscribeToAllLocksProvider(for: $0)
        }
    }

    private func updateHoldsSubscription(from changes: [DataProviderChange<ChainModel>]) {
        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        assetHoldsSubscriptions = changes.reduce(
            intitial: assetHoldsSubscriptions,
            selectedMetaAccount: selectedMetaAccount
        ) { [weak self] in
            self?.subscribeToAllHoldsProvider(for: $0)
        }
    }

    override func handleAccountLocks(result: Result<[DataProviderChange<AssetLock>], Error>, accountId: AccountId) {
        switch result {
        case let .success(changes):
            handleAccountLocksChanges(changes, accountId: accountId)
        case let .failure(error):
            modelBuilder?.applyLocks(.failure(error))
        }
    }

    override func handleAccountHolds(result: Result<[DataProviderChange<AssetHold>], Error>, accountId: AccountId) {
        switch result {
        case let .success(changes):
            handleAccountHoldsChanges(changes, accountId: accountId)
        case let .failure(error):
            modelBuilder?.applyHolds(.failure(error))
        }
    }

    override func handlePriceChanges(_ result: Result<[ChainAssetId: DataProviderChange<PriceData>], Error>) {
        super.handlePriceChanges(result)

        presenter?.didCompleteRefreshing()
    }
}

extension AssetListInteractor: AssetListInteractorInputProtocol {
    func refresh() {
        if let provider = priceSubscription {
            provider.refresh()
        } else {
            presenter?.didCompleteRefreshing()
        }

        nftSubscription?.refresh()
    }

    func setAssetListGroupsStyle(_ style: AssetListGroupsStyle) {
        settingsManager.assetListGroupStyle = style
    }
}

extension AssetListInteractor: NftLocalStorageSubscriber, NftLocalSubscriptionHandler {
    func handleNfts(result: Result<[DataProviderChange<NftModel>], Error>, wallet: MetaAccountModel) {
        let selectedWalletId = selectedWalletSettings.value.identifier
        guard wallet.identifier == selectedWalletId else {
            logger?.warning("Unexpected nft changes for not selected wallet")
            return
        }

        switch result {
        case let .success(changes):
            modelBuilder?.applyNftChanges(changes)
        case let .failure(error):
            logger?.error("Nft error: \(error)")
        }
    }
}

extension AssetListInteractor {
    private func handleAccountLocksChanges(
        _ changes: [DataProviderChange<AssetLock>],
        accountId: AccountId
    ) {
        locks = changes.reduce(
            into: locks
        ) { accum, change in
            switch change {
            case let .insert(lock), let .update(lock):
                let groupIdentifier = AssetBalance.createIdentifier(
                    for: lock.chainAssetId,
                    accountId: lock.accountId
                )
                guard
                    let assetBalanceId = assetBalanceIdMapping[groupIdentifier],
                    assetBalanceId.accountId == accountId else {
                    return
                }

                let chainAssetId = ChainAssetId(
                    chainId: assetBalanceId.chainId,
                    assetId: assetBalanceId.assetId
                )

                var items = accum[chainAssetId] ?? []
                items.addOrReplaceSingle(lock)
                accum[chainAssetId] = items
            case let .delete(deletedIdentifier):
                for chainLocks in accum {
                    accum[chainLocks.key] = chainLocks.value.filter { $0.identifier != deletedIdentifier }
                }
            }
        }

        modelBuilder?.applyLocks(.success(Array(locks.values.flatMap { $0 })))
    }

    private func handleAccountHoldsChanges(
        _ changes: [DataProviderChange<AssetHold>],
        accountId: AccountId
    ) {
        holds = changes.reduce(
            into: holds
        ) { accum, change in
            switch change {
            case let .insert(hold), let .update(hold):
                let groupIdentifier = AssetBalance.createIdentifier(
                    for: hold.chainAssetId,
                    accountId: hold.accountId
                )
                guard
                    let assetBalanceId = assetBalanceIdMapping[groupIdentifier],
                    assetBalanceId.accountId == accountId else {
                    return
                }

                let chainAssetId = ChainAssetId(
                    chainId: assetBalanceId.chainId,
                    assetId: assetBalanceId.assetId
                )

                var items = accum[chainAssetId] ?? []
                items.addOrReplaceSingle(hold)
                accum[chainAssetId] = items
            case let .delete(deletedIdentifier):
                for chainHolds in accum {
                    accum[chainHolds.key] = chainHolds.value.filter { $0.identifier != deletedIdentifier }
                }
            }
        }

        modelBuilder?.applyHolds(.success(Array(holds.values.flatMap { $0 })))
    }
}

extension AssetListInteractor: EventVisitorProtocol {
    func processChainAccountChanged(event _: ChainAccountChanged) {
        provideWalletInfo()

        resetWallet()
    }

    func processSelectedWalletChanged(event _: SelectedWalletSwitched) {
        provideWalletInfo()

        resetWallet()
    }

    func processHideZeroBalances(event _: HideZeroBalancesChanged) {
        provideHidesZeroBalances()
    }
}
