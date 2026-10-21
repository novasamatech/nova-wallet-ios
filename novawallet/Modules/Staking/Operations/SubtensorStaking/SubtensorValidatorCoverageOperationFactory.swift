import Foundation
import Operation_iOS

protocol SubtensorValidatorCoverageOperationFactoryProtocol {
    func createWrapper(for hotkey: AccountId) -> CompoundOperationWrapper<SubtensorValidatorCoverage?>
}

final class SubtensorValidatorCoverageOperationFactory: SubtensorValidatorCoverageOperationFactoryProtocol {
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
            let delegate = self.apiFactory.createDelegateWrapper(for: hotkey, blockHash: blockHash)
            let catalogue = self.catalogueOperationFactory.createCatalogueWrapper()
            let merge = ClosureOperation<SubtensorValidatorCoverage?> {
                let netuids = try catalogue.targetOperation.extractNoCancellableResultData().subnets.map(\.netuid)
                return try SubtensorValidatorCoverage.make(
                    delegate: delegate.targetOperation.extractNoCancellableResultData(),
                    catalogueNetuids: Set(netuids)
                )
            }
            merge.addDependency(delegate.targetOperation)
            merge.addDependency(catalogue.targetOperation)
            return CompoundOperationWrapper(
                targetOperation: merge, dependencies: delegate.allOperations + catalogue.allOperations
            )
        }
        wrapper.addDependency(wrapper: hash)
        return wrapper.insertingHead(operations: hash.allOperations)
    }
}
