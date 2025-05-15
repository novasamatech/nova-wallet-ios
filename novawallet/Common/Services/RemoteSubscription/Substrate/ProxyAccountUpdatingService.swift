import Foundation

protocol ProxyAccountUpdatingServiceProtocol {
    func setupSubscription(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws

    func clearSubscription()
}

class ProxyAccountUpdatingService: ProxyAccountUpdatingServiceProtocol {
    private var proxySubscription: ProxyAccountSubscription?

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
        chainId: ChainModel.Id
    ) throws {
        proxySubscription = ProxyAccountSubscription(
            accountId: accountId,
            chainId: chainId,
            chainRegistry: chainRegistry,
            delegatedAccountSyncService: delegatedAccountSyncService,
            storageFacade: storageFacade,
            operationQueue: operationQueue,
            workingQueue: .init(label: "com.novawallet.proxy.updating", qos: .userInitiated)
        )
    }

    func clearSubscription() {
        proxySubscription = nil
    }
}
