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
    let pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol
    let eventCenter: EventCenterProtocol
    let settingsManager: SettingsManagerProtocol
    let walletConnect: WalletConnectDelegateInputProtocol
    let assetListModelObservable: AssetListModelObservable
    let walletNotificationService: WalletNotificationServiceProtocol

    private var multisigOperationsSubscription: StreamableProvider<Multisig.PendingOperation>?

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
        walletNotificationService: WalletNotificationServiceProtocol,
        nftLocalSubscriptionFactory: NftLocalSubscriptionFactoryProtocol,
        pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol,
        externalBalancesSubscriptionFactory: ExternalBalanceLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        eventCenter: EventCenterProtocol,
        settingsManager: SettingsManagerProtocol,
        currencyManager: CurrencyManagerProtocol,
        walletConnect: WalletConnectDelegateInputProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.nftLocalSubscriptionFactory = nftLocalSubscriptionFactory
        self.pendingMultisigLocalSubscriptionFactory = pendingMultisigLocalSubscriptionFactory
        self.assetListModelObservable = assetListModelObservable
        self.eventCenter = eventCenter
        self.settingsManager = settingsManager
        self.walletConnect = walletConnect
        self.walletNotificationService = walletNotificationService
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

    // MARK: - Overrides

    override func resetWallet() {
        clearNftSubscription()
        clearMultisigOperationsSubscription()
        clearLocksSubscription()
        clearHoldsSubscription()

        providerWalletInfo()
        provideWalletConnectSessionsCount()

        super.resetWallet()
    }

    override func didResetWallet(
        allChanges: [DataProviderChange<ChainModel>],
        enabledChainChanges: [DataProviderChange<ChainModel>]
    ) {
        super.didResetWallet(allChanges: allChanges, enabledChainChanges: enabledChainChanges)

        subscribeMultisigOperationsIfNeeded()
        setupNftSubscription(from: Array(availableChains.values))
        updateLocksSubscription(from: enabledChainChanges)
        updateHoldsSubscription(from: enabledChainChanges)
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

    override func setup() {
        presenter?.didReceiveAssetListGroupStyle(settingsManager.assetListGroupStyle)
        modelBuilder = .init { [weak self] result in
            self?.presenter?.didReceive(result: result)

            self?.assetListModelObservable.state = .init(value: .init(model: result.model))
        }

        providerWalletInfo()

        walletConnect.add(delegate: self)

        provideHidesZeroBalances()
        provideWalletConnectSessionsCount()

        subscribeMultisigOperationsIfNeeded()
        subscribeChains()

        eventCenter.add(observer: self, dispatchIn: .main)

        walletNotificationService.hasUpdatesObservable.addObserver(
            with: self,
            sendStateOnSubscription: true
        ) { [weak self] _, newState in
            self?.presenter?.didReceiveWalletsState(hasUpdates: newState)
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

// MARK: - Private

private extension AssetListInteractor {
    func clearLocksSubscription() {
        assetLocksSubscriptions.values.forEach { $0.removeObserver(self) }
        assetLocksSubscriptions = [:]
        locks = [:]
    }

    func clearHoldsSubscription() {
        assetHoldsSubscriptions.values.forEach { $0.removeObserver(self) }
        assetHoldsSubscriptions = [:]
        holds = [:]
    }

    func subscribeMultisigOperationsIfNeeded() {
        clearMultisigOperationsSubscription()
        modelBuilder?.applyPendingOperationsReset()

        guard
            selectedWalletSettings.value.type == .multisig,
            let multisigAccount = selectedWalletSettings.value.multisigAccount?.anyChainMultisig
        else { return }

        multisigOperationsSubscription = subscribePendingOperations(for: multisigAccount.accountId)
    }

    func providerWalletInfo() {
        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        presenter?.didReceive(
            walletId: selectedMetaAccount.identifier,
            walletIdenticon: selectedMetaAccount.walletIdenticonData(),
            walletType: selectedMetaAccount.type,
            name: selectedMetaAccount.name
        )

        modelBuilder?.applyWallet(selectedMetaAccount)
    }

    func provideHidesZeroBalances() {
        let value = settingsManager.hidesZeroBalances
        presenter?.didReceive(hidesZeroBalances: value)
    }

    func clearNftSubscription() {
        clear(streamableProvider: &nftSubscription)
        nftChainIds = nil
    }

    func clearMultisigOperationsSubscription() {
        clear(streamableProvider: &multisigOperationsSubscription)
    }

    func setupNftSubscription(from allChains: [ChainModel]) {
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

    func handleAccountLocksChanges(
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

    func handleAccountHoldsChanges(
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

    func provideWalletConnectSessionsCount() {
        walletConnect.fetchSessions { [weak self] result in
            guard let selectedMetaAccount = self?.selectedWalletSettings.value else {
                return
            }

            switch result {
            case let .success(connections):
                let walletConnectSessions = connections.filter { $0.wallet == selectedMetaAccount }
                self?.presenter?.didReceiveWalletConnect(sessionsCount: walletConnectSessions.count)
            case let .failure(error):
                self?.presenter?.didReceiveWalletConnect(error: .sessionsFetchFailed(error))
            }
        }
    }

    func updateLocksSubscription(from changes: [DataProviderChange<ChainModel>]) {
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

    func updateHoldsSubscription(from changes: [DataProviderChange<ChainModel>]) {
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
}

// MARK: - AssetListInteractorInputProtocol

extension AssetListInteractor: AssetListInteractorInputProtocol {
    func refresh() {
        if let provider = priceSubscription {
            provider.refresh()
        } else {
            presenter?.didCompleteRefreshing()
        }

        nftSubscription?.refresh()
    }

    func connectWalletConnect(uri: String) {
        walletConnect.connect(uri: uri) { [weak self] error in
            if let error = error {
                self?.presenter?.didReceiveWalletConnect(error: .connectionFailed(error))
            }
        }
    }

    func retryFetchWalletConnectSessionsCount() {
        provideWalletConnectSessionsCount()
    }

    func setAssetListGroupsStyle(_ style: AssetListGroupsStyle) {
        settingsManager.assetListGroupStyle = style
    }
}

// MARK: - NftLocalStorageSubscriber

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

// MARK: - MultisigPendingOperationsSubscriber

extension AssetListInteractor: MultisigOperationsLocalStorageSubscriber,
    MultisigOperationsLocalSubscriptionHandler {
    func handleMultisigPendingOperations(
        result: Result<[DataProviderChange<Multisig.PendingOperation>], any Error>
    ) {
        switch result {
        case let .success(changes):
            modelBuilder?.applyPendingOperationsChanges(changes)
        case let .failure(error):
            logger?.error("Multisig pending operations error: \(error)")
        }
    }
}

// MARK: - EventVisitorProtocol

extension AssetListInteractor: EventVisitorProtocol {
    func processChainAccountChanged(event _: ChainAccountChanged) {
        resetWallet()
    }

    func processSelectedWalletChanged(event _: SelectedWalletSwitched) {
        resetWallet()
    }

    func processWalletNameChanged(event: WalletNameChanged) {
        guard event.isSelectedWallet, let name = selectedWalletSettings.value?.name else {
            return
        }

        presenter?.didChange(name: name)
    }

    func processHideZeroBalances(event _: HideZeroBalancesChanged) {
        provideHidesZeroBalances()
    }
}

// MARK: - WalletConnectDelegateOutputProtocol

extension AssetListInteractor: WalletConnectDelegateOutputProtocol {
    func walletConnectDidChangeSessions() {
        provideWalletConnectSessionsCount()
    }

    func walletConnectDidChangeChains() {
        provideWalletConnectSessionsCount()
    }
}
