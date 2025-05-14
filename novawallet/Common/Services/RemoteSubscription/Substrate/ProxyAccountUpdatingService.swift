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
    let proxySyncService: DelegatedAccountSyncServiceProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol?
    let storageFacade: StorageFacadeProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        proxySyncService: DelegatedAccountSyncServiceProtocol,
        storageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.chainRegistry = chainRegistry
        self.proxySyncService = proxySyncService
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
            proxySyncService: proxySyncService,
            storageFacade: storageFacade,
            operationQueue: operationQueue,
            workingQueue: .init(label: "com.novawallet.proxy.updating", qos: .userInitiated)
        )
    }

    func clearSubscription() {
        proxySubscription = nil
    }
}
