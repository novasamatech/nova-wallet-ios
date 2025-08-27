import Operation_iOS

// Type used to represent ordered collection of accounts grouped by their delegate
typealias DelegatedAccountsByDelegate = [(delegate: AccountId, accounts: [DiscoveredDelegatedAccountProtocol])]

protocol DelegatedAccountsAggregatorProtocol {
    func fetchDelegatedAccountsWrapper(
        for accountIds: [AccountId]
    ) -> CompoundOperationWrapper<DelegatedAccountsByDelegate>
}

final class DelegatedAccountsAggregator {
    private let sources: [DelegatedAccountsRepositoryProtocol]
    private let operationQueue: OperationQueue

    init(
        sources: [DelegatedAccountsRepositoryProtocol],
        operationQueue: OperationQueue
    ) {
        self.sources = sources
        self.operationQueue = operationQueue
    }
}

extension DelegatedAccountsAggregator: DelegatedAccountsAggregatorProtocol {
    func fetchDelegatedAccountsWrapper(
        for accountIds: [AccountId]
    ) -> CompoundOperationWrapper<DelegatedAccountsByDelegate> {
        let accountIdsSet = Set(accountIds)

        let fetchWrappers = sources.map {
            $0.fetchDelegatedAccountsWrapper(for: accountIdsSet)
        }

        let mapOperation = ClosureOperation<DelegatedAccountsByDelegate> {
            let fetchResult = try fetchWrappers
                .map { try $0.targetOperation.extractNoCancellableResultData() }
                .reduce(into: [:]) { $0.merge($1, uniquingKeysWith: { $0 + $1 }) }

            return accountIds.compactMap {
                guard let delegatedAccounts = fetchResult[$0] else { return nil }

                return ($0, delegatedAccounts)
            }
        }

        fetchWrappers.forEach { mapOperation.addDependency($0.targetOperation) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: fetchWrappers.flatMap(\.allOperations)
        )
    }
}
