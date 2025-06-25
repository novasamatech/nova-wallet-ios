import Foundation
import Operation_iOS

protocol MultisigOperationsLocalStorageSubscriber: LocalStorageProviderObserving where Self: AnyObject {
    var multisigOperationsLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol { get }

    var multisigOperationsLocalSubscriptionHandler: MultisigOperationsLocalSubscriptionHandler { get }

    func subscribePendingOperations(
        for accountId: AccountId,
        chainId: ChainModel.Id?
    ) -> StreamableProvider<Multisig.PendingOperation>?
}

extension MultisigOperationsLocalStorageSubscriber {
    func subscribePendingOperations(
        for accountId: AccountId
    ) -> StreamableProvider<Multisig.PendingOperation>? {
        subscribePendingOperations(for: accountId, chainId: nil)
    }
}

extension MultisigOperationsLocalStorageSubscriber {
    func subscribePendingOperations(
        for accountId: AccountId,
        chainId: ChainModel.Id?
    ) -> StreamableProvider<Multisig.PendingOperation>? {
        guard let provider = try? multisigOperationsLocalSubscriptionFactory.getPendingOperatonsProvider(
            for: accountId,
            chainId: chainId
        ) else { return nil }

        addStreamableProviderObserver(
            for: provider,
            updateClosure: { [weak self] (changes: [DataProviderChange<Multisig.PendingOperation>]) in
                self?.multisigOperationsLocalSubscriptionHandler.handleMultisigPendingOperations(result: .success(changes))
                return
            },
            failureClosure: { [weak self] (error: Error) in
                self?.multisigOperationsLocalSubscriptionHandler.handleMultisigPendingOperations(result: .failure(error))
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

extension MultisigOperationsLocalStorageSubscriber where Self: MultisigOperationsLocalSubscriptionHandler {
    var multisigOperationsLocalSubscriptionHandler: MultisigOperationsLocalSubscriptionHandler { self }
}
