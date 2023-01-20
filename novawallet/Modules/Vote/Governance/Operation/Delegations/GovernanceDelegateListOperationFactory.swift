import Foundation
import RobinHood

final class GovernanceDelegateListOperationFactory {
    let chain: ChainModel
    let statsOperationFactory: GovernanceDelegateStatsFactoryProtocol
    let metadataOperationFactory: GovernanceDelegateMetadataFactoryProtocol

    init(
        chain: ChainModel,
        statsOperationFactory: GovernanceDelegateStatsFactoryProtocol,
        metadataOperationFactory: GovernanceDelegateMetadataFactoryProtocol
    ) {
        self.chain = chain
        self.statsOperationFactory = statsOperationFactory
        self.metadataOperationFactory = metadataOperationFactory
    }

    private func createMergeOperation(
        dependingOn statsOperation: BaseOperation<[GovernanceDelegateStats]>,
        metadataOperation: BaseOperation<[GovernanceDelegateMetadataRemote]>
    ) -> BaseOperation<[GovernanceDelegateLocal]> {
        ClosureOperation<[GovernanceDelegateLocal]> {
            let stats = try statsOperation.extractNoCancellableResultData()
            let metadataList = try metadataOperation.extractNoCancellableResultData()

            let initMetadataStore = [AccountId: GovernanceDelegateMetadataRemote]()
            let metadataStore = try metadataList.reduce(into: initMetadataStore) { accum, item in
                let accountId = try item.address.toAccountId()
                accum[accountId] = item
            }

            return try stats.map { statsItem in
                let accountId = try statsItem.address.toAccountId()
                let metadata = metadataStore[accountId]

                return GovernanceDelegateLocal(stats: statsItem, metadata: metadata)
            }
        }
    }
}

extension GovernanceDelegateListOperationFactory: GovernanceDelegateListFactoryProtocol {
    func fetchDelegateListWrapper(
        for activityStartBlock: BlockNumber
    ) -> CompoundOperationWrapper<[GovernanceDelegateLocal]> {
        let statsWrapper = statsOperationFactory.fetchStatsWrapper(for: activityStartBlock)
        let metadataOperation = metadataOperationFactory.fetchMetadataOperation(for: chain)

        let mergeOperation = createMergeOperation(
            dependingOn: statsWrapper.targetOperation,
            metadataOperation: metadataOperation
        )

        mergeOperation.addDependency(statsWrapper.targetOperation)
        mergeOperation.addDependency(metadataOperation)

        let dependencies = statsWrapper.allOperations + [metadataOperation]

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}
