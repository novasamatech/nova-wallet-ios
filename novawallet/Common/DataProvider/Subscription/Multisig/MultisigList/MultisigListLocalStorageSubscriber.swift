import Foundation
import Operation_iOS

protocol MultisigListLocalStorageSubscriber: LocalStorageProviderObserving where Self: AnyObject {
    var multisigListLocalSubscriptionFactory: MultisigListLocalSubscriptionFactoryProtocol { get }

    var multisigListLocalSubscriptionHandler: MultisigListLocalSubscriptionHandler { get }

    func subscribeAllMultisigs() -> StreamableProvider<DelegatedAccount.MultisigAccountModel>?
}

extension MultisigListLocalStorageSubscriber {
    func subscribeAllMultisigs() -> StreamableProvider<DelegatedAccount.MultisigAccountModel>? {
        guard let provider = try? multisigListLocalSubscriptionFactory.getMultisigListProvider() else {
            return nil
        }

        addStreamableProviderObserver(
            for: provider,
            updateClosure: { [weak self] (changes: [DataProviderChange<DelegatedAccount.MultisigAccountModel>]) in
                self?.multisigListLocalSubscriptionHandler.handleAllMultisigs(result: .success(changes))
                return
            },
            failureClosure: { [weak self] (error: Error) in
                self?.multisigListLocalSubscriptionHandler.handleAllMultisigs(result: .failure(error))
                return
            },
            options: StreamableProviderObserverOptions(
                alwaysNotifyOnRefresh: false,
                waitsInProgressSyncOnAdd: false,
                initialSize: 0,
                refreshWhenEmpty: false
            )
        )

        return provider
    }
}

extension MultisigListLocalStorageSubscriber where Self: MultisigListLocalSubscriptionHandler {
    var multisigListLocalSubscriptionHandler: MultisigListLocalSubscriptionHandler { self }
}
