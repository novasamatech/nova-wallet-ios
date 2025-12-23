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

extension BlockNumberCallbackSubscriptionFactory: BlockNumberCallbackSubscriptionFactoryProtocol {
    func createSubscription(for chainId: ChainModel.Id) throws -> BlockNumberRemoteSubscriptionProtocol {
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
