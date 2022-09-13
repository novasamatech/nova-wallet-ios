import Foundation
import RobinHood
import SubstrateSdk
import SoraKeystore
import BigInt

final class AssetListInteractor: AssetListBaseInteractor {
    var presenter: AssetListInteractorOutputProtocol? {
        get {
            basePresenter as? AssetListInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let nftLocalSubscriptionFactory: NftLocalSubscriptionFactoryProtocol
    let eventCenter: EventCenterProtocol
    let settingsManager: SettingsManagerProtocol

    private var nftSubscription: StreamableProvider<NftModel>?
    private var nftChainIds: Set<ChainModel.Id>?
    private var assetLocksSubscriptions: [AccountId: StreamableProvider<AssetLock>] = [:]
    private var locks: [ChainAssetId: [AssetLock]] = [:]

    init(
        selectedWalletSettings: SelectedWalletSettings,
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        nftLocalSubscriptionFactory: NftLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        eventCenter: EventCenterProtocol,
        settingsManager: SettingsManagerProtocol,
        currencyManager: CurrencyManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.nftLocalSubscriptionFactory = nftLocalSubscriptionFactory
        self.eventCenter = eventCenter
        self.settingsManager = settingsManager

        super.init(
            selectedWalletSettings: selectedWalletSettings,
            chainRegistry: chainRegistry,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            currencyManager: currencyManager,
            logger: logger
        )
    }

    private func resetWallet() {
        clearAccountSubscriptions()
        clearNftSubscription()
        clearLocksSubscription()
        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        providerWalletInfo()

        let changes = availableChains.values.filter {
            selectedMetaAccount.fetch(for: $0.accountRequest()) != nil
        }.map {
            DataProviderChange.insert(newItem: $0)
        }

        presenter?.didReceiveChainModelChanges(changes)

        updateAccountInfoSubscription(from: changes)
        setupNftSubscription(from: Array(availableChains.values))
        updateLocksSubscription(from: changes)
    }

    private func clearLocksSubscription() {
        assetLocksSubscriptions.values.forEach { $0.removeObserver(self) }
        assetLocksSubscriptions = [:]
        locks = [:]
    }

    private func providerWalletInfo() {
        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        presenter?.didReceive(
            walletIdenticon: selectedMetaAccount.walletIdenticonData(),
            walletType: selectedMetaAccount.type,
            name: selectedMetaAccount.name
        )
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
        accountDependentChanges: [DataProviderChange<ChainModel>]
    ) {
        super.applyChanges(allChanges: allChanges, accountDependentChanges: accountDependentChanges)

        updateConnectionStatus(from: allChanges)
        setupNftSubscription(from: Array(availableChains.values))
        updateLocksSubscription(from: allChanges)
    }

    private func updateConnectionStatus(from changes: [DataProviderChange<ChainModel>]) {
        for change in changes {
            switch change {
            case let .insert(chain), let .update(chain):
                chainRegistry.subscribeChainState(self, chainId: chain.chainId)
            case let .delete(identifier):
                chainRegistry.unsubscribeChainState(self, chainId: identifier)
            }
        }
    }

    private func setupNftSubscription(from allChains: [ChainModel]) {
        let nftChains = allChains.filter { !$0.nftSources.isEmpty }

        let newNftChainIds = Set(nftChains.map(\.chainId))

        guard !newNftChainIds.isEmpty, newNftChainIds != nftChainIds else {
            return
        }

        clearNftSubscription()

        presenter?.didResetNftProvider()

        nftChainIds = newNftChainIds

        nftSubscription = subscribeToNftProvider(for: selectedWalletSettings.value, chains: nftChains)
        nftSubscription?.refresh()
    }

    override func setup() {
        provideHidesZeroBalances()
        providerWalletInfo()

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

    override func handleAccountLocks(result: Result<[DataProviderChange<AssetLock>], Error>, accountId: AccountId) {
        switch result {
        case let .success(changes):
            handleAccountLocksChanges(changes, accountId: accountId)
        case let .failure(error):
            presenter?.didReceiveLocks(result: .failure(error))
        }
    }
}

extension AssetListInteractor: AssetListInteractorInputProtocol {
    func refresh() {
        if let provider = priceSubscription {
            provider.refresh()
        } else {
            presenter?.didReceivePrices(result: nil)
        }

        nftSubscription?.refresh()
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
            presenter?.didReceiveNft(changes: changes)
        case let .failure(error):
            presenter?.didReceiveNft(error: error)
        }
    }
}

extension AssetListInteractor {
    private func handleAccountLocksChanges(
        _ changes: [DataProviderChange<AssetLock>],
        accountId: AccountId
    ) {
        let initialItems = assetBalanceIdMapping.values.reduce(
            into: [ChainAssetId: [AssetLock]]()
        ) { accum, assetBalanceId in
            guard assetBalanceId.accountId == accountId else {
                return
            }

            let chainAssetId = ChainAssetId(
                chainId: assetBalanceId.chainId,
                assetId: assetBalanceId.assetId
            )

            accum[chainAssetId] = locks[chainAssetId]
        }

        locks = changes.reduce(
            into: initialItems
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

        presenter?.didReceiveLocks(result: .success(Array(locks.values.flatMap { $0 })))
    }
}

extension AssetListInteractor: ConnectionStateSubscription {
    func didReceive(state: WebSocketEngine.State, for chainId: ChainModel.Id) {
        presenter?.didReceive(state: state, for: chainId)
    }
}

extension AssetListInteractor: EventVisitorProtocol {
    func processChainAccountChanged(event _: ChainAccountChanged) {
        resetWallet()
    }

    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        resetWallet()
    }

    func processSelectedUsernameChanged(event _: SelectedUsernameChanged) {
        guard let name = selectedWalletSettings.value?.name else {
            return
        }

        presenter?.didChange(name: name)
    }

    func processHideZeroBalances(event _: HideZeroBalancesChanged) {
        provideHidesZeroBalances()
    }
}
