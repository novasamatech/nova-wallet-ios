import Foundation

protocol MultisigPendingOperationsSubscriber: AnyObject {
    func didReceiveUpdate(
        callHash: CallHash,
        multisigDefinition: MultisigPallet.MultisigDefinition?
    )
}

protocol MultisigPendingOperationsUpdatingServiceProtocol {
    func setupSubscription(
        subscriber: MultisigPendingOperationsSubscriber,
        for multisigAccountId: AccountId,
        callHashes: Set<CallHash>,
        chainId: ChainModel.Id
    )

    func clearSubscription()
}

final class MultisigPendingOperationsUpdatingService {
    private let chainRegistry: ChainRegistryProtocol
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue

    private let mutex = NSLock()

    private var subscription: MultisigPendingOperationsSubscription?

    init(
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = DispatchQueue(label: "com.nova.wallet.pending.multisigs.updating")
    ) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
    }

    deinit {
        clearSubscription()
    }
}

// MARK: - MultisigPendingOperationsUpdatingServiceProtocol

extension MultisigPendingOperationsUpdatingService: MultisigPendingOperationsUpdatingServiceProtocol {
    func setupSubscription(
        subscriber: MultisigPendingOperationsSubscriber,
        for multisigAccountId: AccountId,
        callHashes: Set<CallHash>,
        chainId: ChainModel.Id
    ) {
        guard !callHashes.isEmpty else { return }

        clearSubscription()

        mutex.lock()

        subscription = MultisigPendingOperationsSubscription(
            accountId: multisigAccountId,
            chainId: chainId,
            callHashes: callHashes,
            chainRegistry: chainRegistry,
            subscriber: subscriber,
            operationQueue: operationQueue,
            workingQueue: workingQueue
        )

        mutex.unlock()
    }

    func clearSubscription() {
        mutex.lock()
        defer { mutex.unlock() }

        subscription = nil
    }
}
