import Foundation
import RobinHood
import SubstrateSdk

final class WalletListInteractor {
    weak var presenter: WalletListInteractorOutputProtocol!

    let selectedMetaAccount: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    private var accountInfoSubscriptions: [ChainModel.Id: AnyDataProvider<DecodedAccountInfo>] = [:]
    private var priceSubscription: AnySingleValueProvider<[PriceData]>?
    private var availableTokenPrice: [ChainModel.Id: AssetModel.PriceId] = [:]

    init(
        selectedMetaAccount: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainRegistry = chainRegistry
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
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

        let priceIds = Array(priceIdSet)

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
                // no changes in price
                break
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
        presenter.didReceive(genericAccountId: selectedMetaAccount.substrateAccountId, name: selectedMetaAccount.name)

        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            self?.presenter.didReceiveChainModelChanges(changes)
            self?.updateConnectionStatus(from: changes)
            self?.updateAccountInfoSubscription(from: changes)
            self?.updatePriceSubscription(from: changes)
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
