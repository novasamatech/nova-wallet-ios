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

    func asyncWaitChainAsset(
        for chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<ChainAsset?> {
        let chainWrapper = asyncWaitChainWrapper(for: chainAssetId.chainId)

        let mappingOperation = ClosureOperation<ChainAsset?> {
            let chain = try chainWrapper.targetOperation.extractNoCancellableResultData()

            return chain?.chainAsset(for: chainAssetId.assetId)
        }

        mappingOperation.addDependency(chainWrapper.targetOperation)

        return chainWrapper.insertingTail(operation: mappingOperation)
    }
}
