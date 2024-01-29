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
    let childSubscriptionFactory: ChildSubscriptionFactoryProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        proxySyncService: ProxySyncServiceProtocol,
        childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.chainRegistry = chainRegistry
        self.proxySyncService = proxySyncService
        self.childSubscriptionFactory = childSubscriptionFactory
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
            childSubscriptionFactory: childSubscriptionFactory,
            operationQueue: operationQueue
        )
    }

    func clearSubscription() {
        proxySubscription = nil
    }
}
