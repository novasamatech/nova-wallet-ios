import Foundation
import Operation_iOS

protocol WalletListLocalStorageSubscriber where Self: AnyObject {
    var walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol { get }

    var walletListLocalSubscriptionHandler: WalletListLocalSubscriptionHandler { get }

    func subscribeAllWalletsProvider() -> StreamableProvider<ManagedMetaAccountModel>?

    func subscribeWallet(by walletId: String) -> StreamableProvider<ManagedMetaAccountModel>?

    func subscribeSelectedWalletProvider() -> StreamableProvider<ManagedMetaAccountModel>?

    func subscribeForWallets(of type: MetaAccountModelType) -> StreamableProvider<ManagedMetaAccountModel>?
}

private extension WalletListLocalStorageSubscriber {
    func subscribeWallets(
        provider: StreamableProvider<ManagedMetaAccountModel>,
        updateClosure: @escaping ([DataProviderChange<ManagedMetaAccountModel>]) -> Void,
        failureClosure: @escaping (Error) -> Void
    ) -> StreamableProvider<ManagedMetaAccountModel>? {
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

        return subscribeWallets(
            provider: provider,
            updateClosure: updateClosure,
            failureClosure: failureClosure
        )
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
            self?.walletListLocalSubscriptionHandler.handleWallet(result: .failure(error), for: walletId)
            return
        }

        return subscribeWallets(
            provider: provider,
            updateClosure: updateClosure,
            failureClosure: failureClosure
        )
    }

    func subscribeSelectedWalletProvider() -> StreamableProvider<ManagedMetaAccountModel>? {
        guard let provider = try? walletListLocalSubscriptionFactory.getSelectedWalletProvider() else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<ManagedMetaAccountModel>]) in
            let wallet = changes.reduceToLastChange()

            self?.walletListLocalSubscriptionHandler.handleSelectedWallet(result: .success(wallet))
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.walletListLocalSubscriptionHandler.handleSelectedWallet(result: .failure(error))
            return
        }

        return subscribeWallets(
            provider: provider,
            updateClosure: updateClosure,
            failureClosure: failureClosure
        )
    }

    func subscribeForWallets(of type: MetaAccountModelType) -> StreamableProvider<ManagedMetaAccountModel>? {
        guard let provider = try? walletListLocalSubscriptionFactory.getWalletsProvider(for: type) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<ManagedMetaAccountModel>]) in
            self?.walletListLocalSubscriptionHandler.handleWallets(result: .success(changes), of: type)
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.walletListLocalSubscriptionHandler.handleWallets(result: .failure(error), of: type)
            return
        }

        return subscribeWallets(
            provider: provider,
            updateClosure: updateClosure,
            failureClosure: failureClosure
        )
    }
}

extension WalletListLocalStorageSubscriber where Self: WalletListLocalSubscriptionHandler {
    var walletListLocalSubscriptionHandler: WalletListLocalSubscriptionHandler { self }
}
