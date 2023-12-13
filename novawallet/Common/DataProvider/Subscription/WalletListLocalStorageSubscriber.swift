import Foundation
import RobinHood

protocol WalletListLocalStorageSubscriber where Self: AnyObject {
    var walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol { get }

    var walletListLocalSubscriptionHandler: WalletListLocalSubscriptionHandler { get }

    func subscribeAllWalletsProvider() -> StreamableProvider<ManagedMetaAccountModel>?

    func subscribeWallet(by walletId: String) -> StreamableProvider<ManagedMetaAccountModel>?
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

    func subscribeWallet(by walletId: String) -> StreamableProvider<ManagedMetaAccountModel>? {
        guard let provider = try? walletListLocalSubscriptionFactory.getWalletProvider(for: walletId) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<ManagedMetaAccountModel>]) in
            let wallet = changes.reduceToLastChange()

            self?.walletListLocalSubscriptionHandler.handleWallet(result: .success(wallet), for: walletId)
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
