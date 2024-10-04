import Foundation
import Operation_iOS

extension ChainRegistryProtocol {
    func asyncWaitChainWrapper(
        for chainId: ChainModel.Id,
        workQueue: DispatchQueue = .global()
    ) -> CompoundOperationWrapper<ChainModel?> {
        if let chain = getChain(for: chainId) {
            return .createWithResult(chain)
        }

        let subscriptionId = NSObject()

        let operation = AsyncClosureOperation<ChainModel?>(operationClosure: { [weak self] closure in
            self?.chainsSubscribe(
                subscriptionId,
                runningInQueue: workQueue,
                filterStrategy: .chainId(chainId)
            ) { changes in
                self?.chainsUnsubscribe(subscriptionId)

                let allChains = changes.allChangedItems()
                let chain = allChains.first { $0.chainId == chainId }
                closure(.success(chain))
            }
        }, cancelationClosure: { [weak self] in
            self?.chainsUnsubscribe(subscriptionId)
        })

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
