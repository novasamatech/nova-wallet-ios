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
    let proxySyncService: ProxySyncServiceProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol?
    let storageFacade: StorageFacadeProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        proxySyncService: ProxySyncServiceProtocol,
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
            workingQueue: DispatchQueue.global()
        )
    }

    func clearSubscription() {
        proxySubscription = nil
    }
}
