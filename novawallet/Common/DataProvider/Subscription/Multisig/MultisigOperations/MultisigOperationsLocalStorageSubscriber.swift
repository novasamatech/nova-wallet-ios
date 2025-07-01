import Foundation
import Operation_iOS

protocol MultisigOperationsLocalStorageSubscriber: LocalStorageProviderObserving where Self: AnyObject {
    var pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol { get }

    var pendingMultisigLocalSubscriptionHandler: MultisigOperationsLocalSubscriptionHandler { get }

    func subscribePendingOperations(
        for accountId: AccountId,
        chainId: ChainModel.Id?
    ) -> StreamableProvider<Multisig.PendingOperation>?

    func subscribePendingOperation(
        identifier: String
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
        guard let provider = try? pendingMultisigLocalSubscriptionFactory.getPendingOperatonsProvider(
            for: accountId,
            chainId: chainId
        ) else { return nil }

        addStreamableProviderObserver(
            for: provider,
            updateClosure: { [weak self] (changes: [DataProviderChange<Multisig.PendingOperation>]) in
                self?.pendingMultisigLocalSubscriptionHandler.handleMultisigPendingOperations(result: .success(changes))
                return
            },
            failureClosure: { [weak self] (error: Error) in
                self?.pendingMultisigLocalSubscriptionHandler.handleMultisigPendingOperations(result: .failure(error))
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

    func subscribePendingOperation(
        identifier: String
    ) -> StreamableProvider<Multisig.PendingOperation>? {
        guard let provider = try? pendingMultisigLocalSubscriptionFactory.getPendingOperatonProvider(
            identifier: identifier
        ) else { return nil }

        addStreamableProviderObserver(
            for: provider,
            updateClosure: { [weak self] (changes: [DataProviderChange<Multisig.PendingOperation>]) in
                let item = changes.reduceToLastChange()

                self?.pendingMultisigLocalSubscriptionHandler.handleMultisigPendingOperation(
                    result: .success(item),
                    identifier: identifier
                )
                return
            },
            failureClosure: { [weak self] (error: Error) in
                self?.pendingMultisigLocalSubscriptionHandler.handleMultisigPendingOperation(
                    result: .failure(error),
                    identifier: identifier
                )
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
    var pendingMultisigLocalSubscriptionHandler: MultisigOperationsLocalSubscriptionHandler { self }
}
