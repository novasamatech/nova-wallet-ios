import Operation_iOS

protocol DelegatedAccountsRepositoryProtocol {
    func fetchDelegatedAccountsWrapper(
        for accountIds: Set<AccountId>
    ) -> CompoundOperationWrapper<[AccountId: [DiscoveredDelegatedAccountProtocol]]>
}

final class DelegatedAccountsRepository {
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

extension DelegatedAccountsRepository: DelegatedAccountsRepositoryProtocol {
    func fetchDelegatedAccountsWrapper(
        for accountIds: Set<AccountId>
    ) -> CompoundOperationWrapper<[AccountId: [any DiscoveredDelegatedAccountProtocol]]> {
        let fetchWrappers = sources.map {
            $0.fetchDelegatedAccountsWrapper(for: accountIds)
        }

        let mapOperation = ClosureOperation<[AccountId: [DiscoveredDelegatedAccountProtocol]]> {
            let fetchResult = try fetchWrappers
                .map { try $0.targetOperation.extractNoCancellableResultData() }
                .reduce(into: [:]) { $0.merge($1, uniquingKeysWith: { $0 + $1 }) }

            return fetchResult
        }

        fetchWrappers.forEach { mapOperation.addDependency($0.targetOperation) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: fetchWrappers.flatMap(\.allOperations)
        )
    }
}
