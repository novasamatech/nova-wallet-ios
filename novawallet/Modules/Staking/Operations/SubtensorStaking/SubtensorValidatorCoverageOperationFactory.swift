import Foundation
import Operation_iOS

protocol ValidatorCoverageFactoryProtocol {
    func createWrapper(for hotkey: AccountId) -> CompoundOperationWrapper<SubtensorValidatorCoverage?>
}

final class SubtensorValidatorCoverageFactory: ValidatorCoverageFactoryProtocol {
    let apiFactory: SubtensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(apiFactory: SubtensorApiOperationFactoryProtocol, operationQueue: OperationQueue) {
        self.apiFactory = apiFactory
        self.operationQueue = operationQueue
    }

    func createWrapper(for hotkey: AccountId) -> CompoundOperationWrapper<SubtensorValidatorCoverage?> {
        let hash = apiFactory.createBestBlockHashWrapper()
        let wrapper = OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let blockHash = try hash.targetOperation.extractNoCancellableResultData()
            let delegates = self.apiFactory.createDelegatesWrapper(at: blockHash)
            let dynamic = self.apiFactory.createAllDynamicInfoWrapper(at: blockHash)
            let merge = ClosureOperation<SubtensorValidatorCoverage?> {
                try SubtensorValidatorCoverage.make(
                    hotkey: hotkey,
                    delegates: delegates.targetOperation.extractNoCancellableResultData(),
                    rows: dynamic.targetOperation.extractNoCancellableResultData(),
                    blockHash: blockHash
                )
            }
            merge.addDependency(delegates.targetOperation)
            merge.addDependency(dynamic.targetOperation)
            return CompoundOperationWrapper(
                targetOperation: merge, dependencies: delegates.allOperations + dynamic.allOperations
            )
        }
        wrapper.addDependency(wrapper: hash)
        return wrapper.insertingHead(operations: hash.allOperations)
    }
}
