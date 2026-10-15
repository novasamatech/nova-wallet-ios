import Foundation
import Operation_iOS

protocol ValidatorCoverageFactoryProtocol {
    func createWrapper(for hotkey: AccountId) -> CompoundOperationWrapper<SubtensorValidatorCoverage?>
}

final class SubtensorValidatorCoverageFactory: ValidatorCoverageFactoryProtocol {
    let apiFactory: SubtensorApiOperationFactoryProtocol
    let catalogueService: SubtensorSubnetCatalogueServiceProtocol
    let operationQueue: OperationQueue

    init(
        apiFactory: SubtensorApiOperationFactoryProtocol,
        catalogueService: SubtensorSubnetCatalogueServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.apiFactory = apiFactory
        self.catalogueService = catalogueService
        self.operationQueue = operationQueue
    }

    func createWrapper(for hotkey: AccountId) -> CompoundOperationWrapper<SubtensorValidatorCoverage?> {
        let hash = apiFactory.createBestBlockHashWrapper()
        let wrapper = OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let blockHash = try hash.targetOperation.extractNoCancellableResultData()
            let delegates = self.apiFactory.createDelegatesWrapper(at: blockHash)
            let catalogue = self.catalogueService.createCatalogueWrapper()
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
