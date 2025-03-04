import Foundation
import Operation_iOS

protocol StakingAccountUpdatingServiceProtocol {
    func setupSubscription(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        chainFormat: ChainFormat
    ) throws

    func clearSubscription()
}

class StakingAccountUpdatingService: StakingAccountUpdatingServiceProtocol {
    private var accountSubscription: StakingAccountSubscription?

    let chainRegistry: ChainRegistryProtocol
    let substrateRepositoryFactory: SubstrateRepositoryFactoryProtocol
    let substrateDataProviderFactory: SubstrateDataProviderFactoryProtocol
    let childSubscriptionFactory: ChildSubscriptionFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol?

    init(
        chainRegistry: ChainRegistryProtocol,
        substrateRepositoryFactory: SubstrateRepositoryFactoryProtocol,
        substrateDataProviderFactory: SubstrateDataProviderFactoryProtocol,
        childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.chainRegistry = chainRegistry
        self.substrateRepositoryFactory = substrateRepositoryFactory
        self.substrateDataProviderFactory = substrateDataProviderFactory
        self.childSubscriptionFactory = childSubscriptionFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }

    func setupSubscription(
        for accountId: AccountId,
        chainId: ChainModel.Id,
        chainFormat: ChainFormat
    ) throws {
        let address = try accountId.toAddress(using: chainFormat)
        let stashItemProvider = substrateDataProviderFactory.createStashItemProvider(for: address, chainId: chainId)

        accountSubscription = StakingAccountSubscription(
            accountId: accountId,
            chainId: chainId,
            chainFormat: chainFormat,
            chainRegistry: chainRegistry,
            provider: stashItemProvider,
            childSubscriptionFactory: childSubscriptionFactory,
            operationQueue: operationQueue,
            logger: logger
        )
    }

    func clearSubscription() {
        accountSubscription = nil
    }
}
