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

    func asyncWaitChainForeverWrapper(
        where filter: @escaping (ChainModel) -> Bool,
        workQueue: DispatchQueue = .global()
    ) -> CompoundOperationWrapper<ChainModel?> {
        let subscriptionId = NSObject()

        let operation = AsyncClosureOperation<ChainModel?>(operationClosure: { [weak self] closure in
            self?.chainsSubscribe(
                subscriptionId,
                runningInQueue: workQueue
            ) { changes in
                let allChains = changes.allChangedItems()

                guard let chain = allChains.first(where: { filter($0) }) else { return }

                self?.chainsUnsubscribe(subscriptionId)
                closure(.success(chain))
            }
        }, cancelationClosure: { [weak self] in
            self?.chainsUnsubscribe(subscriptionId)
        })

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func asyncWaitChainOrErrorWrapper(
        for chainId: ChainModel.Id,
        workQueue: DispatchQueue = .global()
    ) -> CompoundOperationWrapper<ChainModel> {
        let wrapper = asyncWaitChainWrapper(for: chainId, workQueue: workQueue)

        let mappingOperation = ClosureOperation<ChainModel> {
            try wrapper.targetOperation.extractNoCancellableResultData().mapOrThrow(
                ChainRegistryError.noChain(chainId)
            )
        }

        mappingOperation.addDependency(wrapper.targetOperation)

        return wrapper.insertingTail(operation: mappingOperation)
    }

    func asyncWaitChainAssetOrError(
        for chainAssetId: ChainAssetId,
        workQueue: DispatchQueue = .global()
    ) -> CompoundOperationWrapper<ChainAsset> {
        let chainWrapper = asyncWaitChainWrapper(for: chainAssetId.chainId, workQueue: workQueue)

        let mappingOperation = ClosureOperation<ChainAsset> {
            let chain = try chainWrapper.targetOperation.extractNoCancellableResultData().mapOrThrow(
                ChainRegistryError.noChain(chainAssetId.chainId)
            )

            return try chain.chainAsset(for: chainAssetId.assetId).mapOrThrow(
                ChainRegistryError.noChainAsset(chainAssetId)
            )
        }

        mappingOperation.addDependency(chainWrapper.targetOperation)

        return chainWrapper.insertingTail(operation: mappingOperation)
    }

    func asyncWaitUtilityAssetOrError(
        for chainId: ChainModel.Id,
        workQueue: DispatchQueue = .global()
    ) -> CompoundOperationWrapper<ChainAsset> {
        let chainWrapper = asyncWaitChainWrapper(for: chainId, workQueue: workQueue)

        let mappingOperation = ClosureOperation<ChainAsset> {
            let chain = try chainWrapper.targetOperation.extractNoCancellableResultData().mapOrThrow(
                ChainRegistryError.noChain(chainId)
            )

            return try chain.utilityChainAsset().mapOrThrow(
                ChainRegistryError.noUtilityAsset(chainId)
            )
        }

        mappingOperation.addDependency(chainWrapper.targetOperation)

        return chainWrapper.insertingTail(operation: mappingOperation)
    }
}
