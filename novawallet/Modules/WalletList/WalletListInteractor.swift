import Foundation
import RobinHood
import SubstrateSdk
import SoraKeystore
import BigInt

final class WalletListInteractor: WalletListBaseInteractor {
    var presenter: WalletListInteractorOutputProtocol? {
        get {
            basePresenter as? WalletListInteractorOutputProtocol
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

    init(
        selectedWalletSettings: SelectedWalletSettings,
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        nftLocalSubscriptionFactory: NftLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        eventCenter: EventCenterProtocol,
        settingsManager: SettingsManagerProtocol,
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
            logger: logger
        )
    }

    private func resetWallet() {
        clearAccountSubscriptions()
        clearNftSubscription()

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
    }

    private func providerWalletInfo() {
        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        presenter?.didReceive(
            genericAccountId: selectedMetaAccount.substrateAccountId,
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

    override func applyChanges(allChanges: [DataProviderChange<ChainModel>], accountDependentChanges: [DataProviderChange<ChainModel>]) {
        super.applyChanges(allChanges: allChanges, accountDependentChanges: accountDependentChanges)

        updateConnectionStatus(from: allChanges)
        setupNftSubscription(from: Array(availableChains.values))
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
}

extension WalletListInteractor: WalletListInteractorInputProtocol {
    func refresh() {
        if let provider = priceSubscription {
            provider.refresh()
        } else {
            presenter?.didReceivePrices(result: nil)
        }

        nftSubscription?.refresh()
    }
}

extension WalletListInteractor: NftLocalStorageSubscriber, NftLocalSubscriptionHandler {
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

extension WalletListInteractor: ConnectionStateSubscription {
    func didReceive(state: WebSocketEngine.State, for chainId: ChainModel.Id) {
        presenter?.didReceive(state: state, for: chainId)
    }
}

extension WalletListInteractor: EventVisitorProtocol {
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
