import Foundation

protocol MultisigPendingOperationsSubscriber: AnyObject {
    func didReceiveUpdate(
        callHash: CallHash,
        multisigDefinition: Multisig.MultisigDefinition?
    )
}

protocol MultisigPendingOperationsUpdatingServiceProtocol {
    func setupSubscription(
        subscriber: MultisigPendingOperationsSubscriber,
        for multisigAccountId: AccountId,
        callHashes: Set<CallHash>,
        chainId: ChainModel.Id
    ) throws

    func clearSubscription()
}

final class MultisigPendingOperationsUpdatingService {
    private let chainRegistry: ChainRegistryProtocol
    private let storageFacade: StorageFacadeProtocol
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue

    private var subscription: MultisigPendingOperationsSubscription?

    init(
        chainRegistry: ChainRegistryProtocol,
        storageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = DispatchQueue(label: "com.nova.wallet.pending.multisigs.updating")
    ) {
        self.chainRegistry = chainRegistry
        self.storageFacade = storageFacade
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
    ) throws {
        clearSubscription()

        subscription = MultisigPendingOperationsSubscription(
            accountId: multisigAccountId,
            chainId: chainId,
            callHashes: callHashes,
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            subscriber: subscriber,
            operationQueue: operationQueue,
            workingQueue: workingQueue
        )
    }

    func clearSubscription() {
        subscription = nil
    }
}
