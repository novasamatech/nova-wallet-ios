import Foundation
import RobinHood

final class WalletListInteractor {
    weak var presenter: WalletListInteractorOutputProtocol!

    let selectedMetaAccount: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    private var accountInfoSubscriptions: [ChainModel.Id: AnyDataProvider<DecodedAccountInfo>] = [:]
    private var priceSubscriptions: [ChainModel.Id: AnySingleValueProvider<PriceData>] = [:]

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

    private func updateAccountInfoSubscription(from changes: [DataProviderChange<ChainModel>]) {
        accountInfoSubscriptions = changes.reduce(into: accountInfoSubscriptions) { (result, change) in
            switch change {
            case .insert(let chain), .update(let chain):
                guard
                    result[chain.chainId] == nil,
                    let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId else {
                    return
                }

                result[chain.chainId] = subscribeToAccountInfoProvider(
                    for: accountId,
                    chainId: chain.chainId
                )
            case .delete(let deletedIdentifier):
                result[deletedIdentifier] = nil
            }
        }
    }

    private func updatePriceSubscription(from changes: [DataProviderChange<ChainModel>]) {
        for change in changes {
            switch change {
            case .insert(let chain), .update(let chain):
                if let asset = chain.utilityAssets().first, let priceId = asset.priceId {
                    priceSubscriptions[chain.chainId] = subscribeToPrice(for: priceId)
                } else {
                    priceSubscriptions[chain.chainId] = nil
                }
            case .delete(let deletedIdentifier):
                priceSubscriptions[deletedIdentifier] = nil
            }
        }
    }
}

extension WalletListInteractor: WalletListInteractorInputProtocol {
    func setup() {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            self?.presenter.didReceiveChainModelChanges(changes)
            self?.updateAccountInfoSubscription(from: changes)
            self?.updatePriceSubscription(from: changes)
        }
    }
}

extension WalletListInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId: AccountId, chainId: ChainModel.Id) {

    }
}

extension WalletListInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {

    }
}
