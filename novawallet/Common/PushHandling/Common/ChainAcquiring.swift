import Foundation

protocol ChainAcquiring {
    var chainRegistry: ChainRegistryProtocol { get }
    var operationQueue: OperationQueue { get }
    var workingQueue: DispatchQueue { get }

    var callStore: CancellableCallStore { get }
}

extension ChainAcquiring {
    func getChain(
        for chainId: ChainModel.Id,
        completion: @escaping (ChainModel) -> Void
    ) {
        let chainWrapper = chainRegistry.asyncWaitChainForeverWrapper(
            where: { Web3Alert.createRemoteChainId(from: $0.chainId) == chainId },
            workQueue: workingQueue
        )

        executeCancellable(
            wrapper: chainWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workingQueue
        ) { result in
            guard let chain = try? result.get() else {
                return
            }

            completion(chain)
        }
    }
}
