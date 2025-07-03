import Foundation

protocol MultisigPendingOperationsSubscriber: AnyObject {
    func didReceiveUpdate(
        callHash: Substrate.CallHash,
        multisigDefinition: MultisigDefinitionWithTime?
    )
}

protocol MultisigPendingOperationsUpdatingServiceProtocol {
    func setupSubscription(
        subscriber: MultisigPendingOperationsSubscriber,
        for multisigAccountId: AccountId,
        callHashes: Set<Substrate.CallHash>,
        chainId: ChainModel.Id
    )

    func clearSubscription()
}

final class MultisigPendingOperationsUpdatingService {
    private let chainRegistry: ChainRegistryProtocol
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    private let logger: LoggerProtocol

    private let mutex = NSLock()

    private var subscription: MultisigPendingOperationsSubscription?

    init(
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = DispatchQueue(label: "com.nova.wallet.pending.multisigs.updating"),
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger
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
        callHashes: Set<Substrate.CallHash>,
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
            workingQueue: workingQueue,
            logger: logger
        )

        mutex.unlock()
    }

    func clearSubscription() {
        mutex.lock()
        defer { mutex.unlock() }

        subscription = nil
    }
}
