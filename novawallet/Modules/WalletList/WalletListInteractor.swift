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

    private var assetBalanceSubscriptions: [ChainAssetId: StreamableProvider<AssetBalance>] = [:]
    private var priceSubscription: AnySingleValueProvider<[PriceData]>?
    private var availableTokenPrice: [ChainAssetId: AssetModel.PriceId] = [:]
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
        assetBalanceSubscriptions.values.forEach { $0.removeObserver(self) }
        assetBalanceSubscriptions = [:]
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

        assetBalanceSubscriptions = changes.reduce(into: assetBalanceSubscriptions) { result, change in
            switch change {
            case let .insert(chain), let .update(chain):
                let allChainAssetIds = result.keys

                for chainAssetId in allChainAssetIds where chainAssetId.chainId == chain.chainId {
                    result[chainAssetId]?.removeObserver(self)
                    result[chainAssetId] = nil
                }

                guard let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId else {
                    return
                }

                for asset in chain.assets {
                    let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)

                    result[chainAssetId] = subscribeToAssetBalanceProvider(
                        for: accountId,
                        chainId: chainAssetId.chainId,
                        assetId: chainAssetId.assetId
                    )
                }
            case let .delete(deletedIdentifier):
                let allChainAssetIds = result.keys

                for chainAssetId in allChainAssetIds where chainAssetId.chainId == deletedIdentifier {
                    result[chainAssetId]?.removeObserver(self)
                    result[chainAssetId] = nil
                }
            }
        }
    }

    private func updatePriceSubscription(from changes: [DataProviderChange<ChainModel>]) {
        let prevPrices = availableTokenPrice
        for change in changes {
            switch change {
            case let .insert(chain), let .update(chain):
                availableTokenPrice = availableTokenPrice.filter { $0.key.chainId != chain.chainId }

                availableTokenPrice = chain.assets.reduce(into: availableTokenPrice) { result, asset in
                    guard let priceId = asset.priceId else {
                        return
                    }

                    let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)
                    result[chainAssetId] = priceId
                }
            case let .delete(deletedIdentifier):
                availableTokenPrice = availableTokenPrice.filter { $0.key.chainId != deletedIdentifier }
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
                    into: [ChainAssetId: PriceData]()
                ) { result, item in
                    guard let chainAssetIds = self?.availableTokenPrice.filter({ $0.value == item.0 })
                        .map(\.key) else {
                        return
                    }

                    for chainAssetId in chainAssetIds {
                        result[chainAssetId] = item.1
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
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard
            let chain = availableChains[chainId],
            let asset = chain.assets.first(where: { $0.assetId == assetId }) else {
            return
        }

        do {
            let balance = try result.get()?.totalInPlank ?? 0

            presenter.didReceiveBalance(
                result: .success(balance),
                chainId: chain.chainId,
                assetId: asset.assetId
            )
        } catch {
            presenter.didReceiveBalance(
                result: .failure(error),
                chainId: chain.chainId,
                assetId: asset.assetId
            )
        }
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
