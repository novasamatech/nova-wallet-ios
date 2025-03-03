import Foundation
import Operation_iOS
import SubstrateSdk

protocol TransactionHistoryLocalFilterFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<TransactionHistoryLocalFilterProtocol>
}

final class TransactionHistoryLocalFilterFactory {
    let providers: [TransactionHistoryFilterProviderProtocol]
    let logger: LoggerProtocol

    init(providers: [TransactionHistoryFilterProviderProtocol], logger: LoggerProtocol) {
        self.providers = providers
        self.logger = logger
    }
}

extension TransactionHistoryLocalFilterFactory: TransactionHistoryLocalFilterFactoryProtocol {
    func createWrapper() -> CompoundOperationWrapper<TransactionHistoryLocalFilterProtocol> {
        let wrappers = providers.map { $0.createFiltersWrapper() }

        let mergeOperation = ClosureOperation<TransactionHistoryLocalFilterProtocol> { [weak self] in
            let filters: [TransactionHistoryLocalFilterProtocol] = wrappers.flatMap { wrapper in
                do {
                    return try wrapper.targetOperation.extractNoCancellableResultData()
                } catch {
                    // don't block if something wrong with the filter
                    self?.logger.warning("Couldn't fetch filter: \(error)")
                    return []
                }
            }

            return TransactionHistoryAndPredicate(innerFilters: filters)
        }

        wrappers.forEach { mergeOperation.addDependency($0.targetOperation) }

        let dependencies = wrappers.flatMap(\.allOperations)

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }
}
