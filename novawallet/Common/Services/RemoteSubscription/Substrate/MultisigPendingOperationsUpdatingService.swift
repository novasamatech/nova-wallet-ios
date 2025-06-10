import Foundation

protocol MultisigPendingOperationsUpdatingServiceProtocol {
    func setupSubscription(
        for accountId: AccountId,
        callHashes: Set<CallHash>,
        chainId: ChainModel.Id
    ) throws

    func clearSubscription()
}

class MultisigPendingOperationsUpdatingService: MultisigPendingOperationsUpdatingServiceProtocol {
    private var multisigOperationsSubscription: MultisigPendingOperationsSubscription?

    let chainRegistry: ChainRegistryProtocol
    let delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol?
    let storageFacade: StorageFacadeProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol,
        storageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.chainRegistry = chainRegistry
        self.delegatedAccountSyncService = delegatedAccountSyncService
        self.storageFacade = storageFacade
        self.operationQueue = operationQueue
        self.logger = logger
    }

    func setupSubscription(
        for accountId: AccountId,
        callHashes: Set<CallHash>,
        chainId: ChainModel.Id
    ) throws {
        
        multisigOperationsSubscription = MultisigPendingOperationsSubscription(
            accountId: accountId,
            chainId: chainId,
            callHashes: callHashes,
            chainRegistry: chainRegistry,
            delegatedAccountSyncService: delegatedAccountSyncService,
            storageFacade: storageFacade,
            operationQueue: operationQueue,
            workingQueue: .init(label: "com.novawallet.multisig.updating", qos: .userInitiated)
        )
    }

    func clearSubscription() {
        multisigOperationsSubscription = nil
    }
}
