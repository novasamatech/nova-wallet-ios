import Foundation

protocol TransactionSubscriptionFactoryProtocol {
    func createTransactionSubscription(
        for accountId: AccountId,
        chain: ChainModel
    ) throws -> TransactionSubscribing
}

final class TransactionSubscriptionFactory {
    let chainRegistry: ChainRegistryProtocol
    let eventCenter: EventCenterProtocol
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let mutex = NSLock()
    private var sharedSubscriptions: [ChainAccountId: WeakWrapper] = [:]

    init(
        chainRegistry: ChainRegistryProtocol,
        eventCenter: EventCenterProtocol,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.eventCenter = eventCenter
        self.repositoryFactory = repositoryFactory
        self.storageRequestFactory = storageRequestFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension TransactionSubscriptionFactory {
    func findSubscription(for accountId: AccountId, chain: ChainModel) -> TransactionSubscription? {
        let identifier = ChainAccountId(chainId: chain.chainId, accountId: accountId)

        guard let subscription = sharedSubscriptions[identifier]?.target as? TransactionSubscription else {
            return nil
        }

        return subscription
    }

    func storeSubscription(_ subscription: TransactionSubscription, accountId: AccountId, chain: ChainModel) {
        let identifier = ChainAccountId(chainId: chain.chainId, accountId: accountId)
        sharedSubscriptions[identifier] = WeakWrapper(target: subscription)
    }

    func setupAndSave(for accountId: AccountId, chain: ChainModel) throws -> TransactionSubscription {
        let address = try accountId.toAddress(using: chain.chainFormat)
        let txStorage = repositoryFactory.createChainAddressTxRepository(
            for: address,
            chainId: chain.chainId
        )

        let subscription = TransactionSubscription(
            chainRegistry: chainRegistry,
            accountId: accountId,
            chainModel: chain,
            txStorage: txStorage,
            storageRequestFactory: storageRequestFactory,
            operationQueue: operationQueue,
            eventCenter: eventCenter,
            logger: logger
        )

        storeSubscription(subscription, accountId: accountId, chain: chain)

        return subscription
    }
}

extension TransactionSubscriptionFactory: TransactionSubscriptionFactoryProtocol {
    func createTransactionSubscription(
        for accountId: AccountId,
        chain: ChainModel
    ) throws -> TransactionSubscribing {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let existingSubscription = findSubscription(for: accountId, chain: chain) {
            return existingSubscription
        }

        return try setupAndSave(for: accountId, chain: chain)
    }
}
