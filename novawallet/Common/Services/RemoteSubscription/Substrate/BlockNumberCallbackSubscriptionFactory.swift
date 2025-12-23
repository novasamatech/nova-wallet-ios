import Foundation
import SubstrateSdk

protocol BlockNumberCallbackSubscriptionFactoryProtocol {
    func createSubscription(for chainId: ChainModel.Id) throws -> BlockNumberRemoteSubscriptionProtocol
}

final class BlockNumberCallbackSubscriptionFactory {
    private lazy var localKeyFactory = LocalStorageKeyFactory()

    let chainRegistry: ChainRegistryProtocol

    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue

    var subscriptions: [ChainModel.Id: WeakWrapper] = [:]

    let mutex = NSLock()

    init(
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue
    ) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
    }
}

private extension BlockNumberCallbackSubscriptionFactory {
    func createNewSubscription(for chainId: ChainModel.Id) throws -> BlockNumberRemoteSubscriptionProtocol {
        BlockNumberRemoteSubscription(
            chainId: chainId,
            connection: try chainRegistry.getConnectionOrError(for: chainId),
            runtimeProvider: try chainRegistry.getRuntimeProviderOrError(for: chainId),
            operationQueue: operationQueue,
            workingQueue: workingQueue,
            localKeyFactory: localKeyFactory
        )
    }
}

extension BlockNumberCallbackSubscriptionFactory: BlockNumberCallbackSubscriptionFactoryProtocol {
    func createSubscription(for chainId: ChainModel.Id) throws -> BlockNumberRemoteSubscriptionProtocol {
        mutex.lock()
        defer { mutex.unlock() }

        guard
            let weakWrapper = subscriptions[chainId],
            let subscription = weakWrapper.target as? BlockNumberRemoteSubscriptionProtocol
        else {
            let subscription = try createNewSubscription(for: chainId)

            subscriptions[chainId] = WeakWrapper(target: subscription)

            return subscription
        }

        return subscription
    }
}
