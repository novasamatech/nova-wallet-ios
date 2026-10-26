import Foundation
import Operation_iOS

protocol SubtensorValidatorCoverageOperationFactoryProtocol {
    func createWrapper(for hotkey: AccountId) -> CompoundOperationWrapper<SubtensorValidatorCoverage?>
}

final class SubtensorValidatorCoverageOperationFactory: SubtensorValidatorCoverageOperationFactoryProtocol {
    let apiFactory: SubtensorApiOperationFactoryProtocol
    let catalogueOperationFactory: SubtensorSubnetCatalogueOperationFactoryProtocol
    let chainOperationFactory: SubtensorValidatorChainOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        apiFactory: SubtensorApiOperationFactoryProtocol,
        chainOperationFactory: SubtensorValidatorChainOperationFactoryProtocol,
        catalogueOperationFactory: SubtensorSubnetCatalogueOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.apiFactory = apiFactory
        self.chainOperationFactory = chainOperationFactory
        self.catalogueOperationFactory = catalogueOperationFactory
        self.operationQueue = operationQueue
    }

    func createWrapper(for hotkey: AccountId) -> CompoundOperationWrapper<SubtensorValidatorCoverage?> {
        let hash = apiFactory.createBestBlockHashWrapper()
        let catalogue = catalogueOperationFactory.createCatalogueWrapper()

        let wrapper = OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let blockHash = try hash.targetOperation.extractNoCancellableResultData()
            let netuids = try catalogue.targetOperation.extractNoCancellableResultData().subnets.map(\.netuid)

            let delegate = self.apiFactory.createDelegateWrapper(for: hotkey, blockHash: blockHash)
            let pairs = netuids.map { SubtensorHotkeySubnet(hotkey: hotkey, netuid: $0) }
            let children = self.chainOperationFactory.createChildKeyLinkedPairsWrapper(for: pairs)

            let merge = ClosureOperation<SubtensorValidatorCoverage?> {
                try SubtensorValidatorCoverage.make(
                    delegate: delegate.targetOperation.extractNoCancellableResultData(),
                    childNetuids: Set(children.targetOperation.extractNoCancellableResultData().map(\.netuid)),
                    catalogueNetuids: Set(netuids)
                )
            }
            merge.addDependency(delegate.targetOperation)
            merge.addDependency(children.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: merge, dependencies: delegate.allOperations + children.allOperations
            )
        }
        wrapper.addDependency(wrapper: hash)
        wrapper.addDependency(wrapper: catalogue)

        return wrapper.insertingHead(operations: hash.allOperations + catalogue.allOperations)
    }
}
