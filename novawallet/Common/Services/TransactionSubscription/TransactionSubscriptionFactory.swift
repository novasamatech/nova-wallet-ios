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

extension TransactionSubscriptionFactory: TransactionSubscriptionFactoryProtocol {
    func createTransactionSubscription(
        for accountId: AccountId,
        chain: ChainModel
    ) throws -> TransactionSubscribing {
        let address = try accountId.toAddress(using: chain.chainFormat)
        let txStorage = repositoryFactory.createChainAddressTxRepository(
            for: address,
            chainId: chain.chainId
        )

        return TransactionSubscription(
            chainRegistry: chainRegistry,
            accountId: accountId,
            chainModel: chain,
            txStorage: txStorage,
            storageRequestFactory: storageRequestFactory,
            operationQueue: operationQueue,
            eventCenter: eventCenter,
            logger: logger
        )
    }
}
