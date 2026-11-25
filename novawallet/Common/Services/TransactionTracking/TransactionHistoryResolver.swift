import Foundation
import Operation_iOS

final class TransactionHistoryResolver {
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }
}

extension TransactionHistoryResolver: TransactionHistoryResolving {
    func createResolutionWrapper(
        for key: TransactionTrackingKey,
        outcome: TransactionTrackingOutcome
    ) -> CompoundOperationWrapper<Void> {
        let filter = NSPredicate.filterTransactionsBy(chainId: key.chainId, transactionHash: key.transactionHash)

        let fetchRepository: CoreDataRepository<TransactionHistoryItem, CDTransactionItem> =
            storageFacade.createRepository(filter: filter, sortDescriptors: [])

        let saveRepository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(TransactionHistoryResolutionMapper())
        )

        let fetchOperation = fetchRepository.fetchAllOperation(with: RepositoryFetchOptions())

        let saveOperation = saveRepository.saveOperation({
            let rows = try fetchOperation.extractNoCancellableResultData()

            return rows.map { TransactionHistoryResolutionMapper.Model(identifier: $0.identifier, outcome: outcome) }
        }, { [] })

        saveOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: saveOperation, dependencies: [fetchOperation])
    }
}
