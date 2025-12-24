import Foundation

protocol WalletRemoteSubscriptionFactoryProtocol {
    func createSubscription() -> WalletRemoteSubscriptionProtocol
}

final class WalletRemoteSubscriptionFactory: WalletRemoteSubscriptionFactoryProtocol {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.logger = logger
    }

    func createSubscription() -> WalletRemoteSubscriptionProtocol {
        WalletRemoteSubscription(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            logger: logger
        )
    }
}
