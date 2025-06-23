import Foundation
import Operation_iOS

protocol MultisigListLocalStorageSubscriber where Self: AnyObject {
    var multisigListLocalSubscriptionFactory: MultisigListLocalSubscriptionFactoryProtocol { get }

    var multisigListLocalSubscriptionHandler: MultisigListLocalSubscriptionHandler { get }

    func subscribeAllMultisigs() -> StreamableProvider<DelegatedAccount.MultisigAccountModel>?
    func subscribePendingOperations(for accountId: AccountId) -> StreamableProvider<Multisig.PendingOperation>?
}

extension MultisigListLocalStorageSubscriber {
    func subscribeAllMultisigs() -> StreamableProvider<DelegatedAccount.MultisigAccountModel>? {
        guard let provider = try? multisigListLocalSubscriptionFactory.getMultisigListProvider() else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DelegatedAccount.MultisigAccountModel>]) in
            self?.multisigListLocalSubscriptionHandler.handleAllMultisigs(result: .success(changes))
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.multisigListLocalSubscriptionHandler.handleAllMultisigs(result: .failure(error))
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

    func subscribePendingOperations(for accountId: AccountId) -> StreamableProvider<Multisig.PendingOperation>? {
        guard let provider = try? multisigListLocalSubscriptionFactory.getPendingOperatonsProvider(
            for: accountId
        ) else { return nil }

        let updateClosure = { [weak self] (changes: [DataProviderChange<Multisig.PendingOperation>]) in
            self?.multisigListLocalSubscriptionHandler.handleMultisigPendingOperations(result: .success(changes))
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.multisigListLocalSubscriptionHandler.handleMultisigPendingOperations(result: .failure(error))
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

extension MultisigListLocalStorageSubscriber where Self: MultisigListLocalSubscriptionHandler {
    var multisigListLocalSubscriptionHandler: MultisigListLocalSubscriptionHandler { self }
}
