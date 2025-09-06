import Operation_iOS
import Foundation

protocol DelegatedAccountsAggregatorProtocol {
    func fetchDelegatedAccountsWrapper(
        for accountIds: Set<AccountId>
    ) -> CompoundOperationWrapper<[DiscoveredDelegatedAccountProtocol]>
}

final class DelegatedAccountsAggregator {
    let sources: [DelegatedAccountsRepositoryProtocol]

    init(sources: [DelegatedAccountsRepositoryProtocol]) {
        self.sources = sources
    }
}

extension DelegatedAccountsAggregator: DelegatedAccountsAggregatorProtocol {
    func fetchDelegatedAccountsWrapper(
        for accountIds: Set<AccountId>
    ) -> CompoundOperationWrapper<[DiscoveredDelegatedAccountProtocol]> {
        let fetchWrappers = sources.map {
            $0.fetchDelegatedAccountsWrapper(for: accountIds)
        }

        let mapOperation = ClosureOperation<[DiscoveredDelegatedAccountProtocol]> {
            try fetchWrappers.flatMap { wrapper in
                let mappings = try wrapper.targetOperation.extractNoCancellableResultData()
                return mappings.values.flatMap { $0 }
            }
        }

        fetchWrappers.forEach { mapOperation.addDependency($0.targetOperation) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: fetchWrappers.flatMap(\.allOperations)
        )
    }
}
