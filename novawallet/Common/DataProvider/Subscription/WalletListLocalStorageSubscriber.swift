import Foundation
import RobinHood

protocol WalletListLocalStorageSubscriber where Self: AnyObject {
    var walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol { get }

    var walletListLocalSubscriptionHandler: WalletListLocalSubscriptionHandler { get }

    func subscribeAllWalletsProvider() -> StreamableProvider<ManagedMetaAccountModel>?
}

extension WalletListLocalStorageSubscriber {
    func subscribeAllWalletsProvider() -> StreamableProvider<ManagedMetaAccountModel>? {
        guard let provider = try? walletListLocalSubscriptionFactory.getWalletsProvider() else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<ManagedMetaAccountModel>]) in
            self?.walletListLocalSubscriptionHandler.handleAllWallets(result: .success(changes))
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.walletListLocalSubscriptionHandler.handleAllWallets(result: .failure(error))
            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: false
        )

        provider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return provider
    }
}

extension WalletListLocalStorageSubscriber where Self: WalletListLocalSubscriptionHandler {
    var walletListLocalSubscriptionHandler: WalletListLocalSubscriptionHandler { self }
}
