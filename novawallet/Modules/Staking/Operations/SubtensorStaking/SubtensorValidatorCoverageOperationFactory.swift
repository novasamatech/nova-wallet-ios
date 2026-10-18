import Foundation
import Operation_iOS

protocol SubtensorValidatorCoverageFactoryProtocol {
    func createWrapper(for hotkey: AccountId) -> CompoundOperationWrapper<SubtensorValidatorCoverage?>
}

final class SubtensorValidatorCoverageFactory: SubtensorValidatorCoverageFactoryProtocol {
    let apiFactory: SubtensorApiOperationFactoryProtocol
    let catalogueOperationFactory: SubtensorSubnetCatalogueOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        apiFactory: SubtensorApiOperationFactoryProtocol,
        catalogueOperationFactory: SubtensorSubnetCatalogueOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.apiFactory = apiFactory
        self.catalogueOperationFactory = catalogueOperationFactory
        self.operationQueue = operationQueue
    }

    func createWrapper(for hotkey: AccountId) -> CompoundOperationWrapper<SubtensorValidatorCoverage?> {
        let hash = apiFactory.createBestBlockHashWrapper()
        let wrapper = OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let blockHash = try hash.targetOperation.extractNoCancellableResultData()
            let delegates = self.apiFactory.createDelegatesWrapper(at: blockHash)
            let catalogue = self.catalogueOperationFactory.createCatalogueWrapper()
            let merge = ClosureOperation<SubtensorValidatorCoverage?> {
                let netuids = try catalogue.targetOperation.extractNoCancellableResultData().subnets.map(\.netuid)
                return try SubtensorValidatorCoverage.make(
                    hotkey: hotkey,
                    delegates: delegates.targetOperation.extractNoCancellableResultData(),
                    catalogueNetuids: Set(netuids)
                )
            }
            merge.addDependency(delegates.targetOperation)
            merge.addDependency(catalogue.targetOperation)
            return CompoundOperationWrapper(
                targetOperation: merge, dependencies: delegates.allOperations + catalogue.allOperations
            )
        }
        wrapper.addDependency(wrapper: hash)
        return wrapper.insertingHead(operations: hash.allOperations)
    }
}
