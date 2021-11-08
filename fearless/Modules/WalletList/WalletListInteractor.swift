import Foundation
import RobinHood
import SubstrateSdk

final class WalletListInteractor {
    weak var presenter: WalletListInteractorOutputProtocol!

    let selectedWalletSettings: SelectedWalletSettings
    let chainRegistry: ChainRegistryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let eventCenter: EventCenterProtocol

    private var accountInfoSubscriptions: [ChainModel.Id: AnyDataProvider<DecodedAccountInfo>] = [:]
    private var priceSubscription: AnySingleValueProvider<[PriceData]>?
    private var availableTokenPrice: [ChainModel.Id: AssetModel.PriceId] = [:]
    private var availableChains: [ChainModel.Id: ChainModel] = [:]

    init(
        selectedWalletSettings: SelectedWalletSettings,
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.chainRegistry = chainRegistry
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.eventCenter = eventCenter
    }

    private func resetWallet() {
        clearAccountSubscriptions()

        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        providerWalletInfo()

        let changes = availableChains.values.filter {
            selectedMetaAccount.fetch(for: $0.accountRequest()) != nil
        }.map {
            DataProviderChange.insert(newItem: $0)
        }

        presenter.didReceiveChainModelChanges(changes)

        updateAccountInfoSubscription(from: changes)
    }

    private func providerWalletInfo() {
        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        presenter.didReceive(
            genericAccountId: selectedMetaAccount.substrateAccountId,
            name: selectedMetaAccount.name
        )
    }

    private func clearAccountSubscriptions() {
        accountInfoSubscriptions.values.forEach { $0.removeObserver(self) }
        accountInfoSubscriptions = [:]
    }

    private func handle(changes: [DataProviderChange<ChainModel>]) {
        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        let actualChanges = changes.filter { change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                return selectedMetaAccount.fetch(for: newItem.accountRequest()) != nil ? true : false
            case .delete:
                return true
            }
        }

        presenter.didReceiveChainModelChanges(actualChanges)
        updateAvailableChains(from: changes)
        updateAccountInfoSubscription(from: actualChanges)
        updateConnectionStatus(from: changes)
        updatePriceSubscription(from: changes)
    }

    private func updateAvailableChains(from changes: [DataProviderChange<ChainModel>]) {
        for change in changes {
            switch change {
            case let .insert(newItem), let .update(newItem):
                availableChains[newItem.chainId] = newItem
            case let .delete(deletedIdentifier):
                availableChains[deletedIdentifier] = nil
            }
        }
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

    private func updateAccountInfoSubscription(from changes: [DataProviderChange<ChainModel>]) {
        guard let selectedMetaAccount = selectedWalletSettings.value else {
            return
        }

        accountInfoSubscriptions = changes.reduce(into: accountInfoSubscriptions) { result, change in
            switch change {
            case let .insert(chain), let .update(chain):
                guard
                    result[chain.chainId] == nil,
                    let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId else {
                    return
                }

                result[chain.chainId] = subscribeToAccountInfoProvider(
                    for: accountId,
                    chainId: chain.chainId
                )
            case let .delete(deletedIdentifier):
                result[deletedIdentifier] = nil
            }
        }
    }

    private func updatePriceSubscription(from changes: [DataProviderChange<ChainModel>]) {
        let prevPrices = availableTokenPrice
        for change in changes {
            switch change {
            case let .insert(chain), let .update(chain):
                availableTokenPrice = availableTokenPrice.filter { $0.key != chain.chainId }

                if let asset = chain.utilityAssets().first, let priceId = asset.priceId {
                    availableTokenPrice[chain.chainId] = priceId
                }
            case let .delete(deletedIdentifier):
                availableTokenPrice = availableTokenPrice.filter { $0.key != deletedIdentifier }
            }
        }

        if prevPrices != availableTokenPrice {
            updatePriceProvider(for: Set(availableTokenPrice.values))
        }
    }

    private func updatePriceProvider(for priceIdSet: Set<AssetModel.PriceId>) {
        priceSubscription = nil

        let priceIds = Array(priceIdSet).sorted()

        guard !priceIds.isEmpty else {
            return
        }

        priceSubscription = priceLocalSubscriptionFactory.getPriceListProvider(for: priceIds)

        let updateClosure = { [weak self] (changes: [DataProviderChange<[PriceData]>]) in
            let finalValue = changes.reduceToLastChange()

            switch finalValue {
            case let .some(prices):
                let chainPrices = zip(priceIds, prices).reduce(
                    into: [ChainModel.Id: PriceData]()
                ) { result, item in
                    guard let chainIds = self?.availableTokenPrice.filter({ $0.value == item.0 })
                        .map(\.key) else {
                        return
                    }

                    for chainId in chainIds {
                        result[chainId] = item.1
                    }
                }

                self?.presenter.didReceivePrices(result: .success(chainPrices))
            case .none:
                self?.presenter.didReceivePrices(result: nil)
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceivePrices(result: .failure(error))
            return
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true, waitsInProgressSyncOnAdd: true)

        priceSubscription?.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }
}

extension WalletListInteractor: WalletListInteractorInputProtocol {
    func setup() {
        providerWalletInfo()

        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            self?.handle(changes: changes)
        }

        eventCenter.add(observer: self, dispatchIn: .main)
    }

    func refresh() {
        if let provider = priceSubscription {
            provider.refresh()
        } else {
            presenter.didReceivePrices(result: nil)
        }
    }
}

extension WalletListInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainId: ChainModel.Id) {
        presenter.didReceiveAccountInfo(result: result, chainId: chainId)
    }
}

extension WalletListInteractor: ConnectionStateSubscription {
    func didReceive(state: WebSocketEngine.State, for chainId: ChainModel.Id) {
        presenter.didReceive(state: state, for: chainId)
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

        presenter.didChange(name: name)
    }
}
