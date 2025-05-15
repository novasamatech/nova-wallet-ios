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
        let accountsFetchOperation = OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            self.sources.map {
                $0.fetchDelegatedAccountsWrapper(for: accountIds)
            }
        }.longrunOperation()

        let mapOperation = ClosureOperation<[AccountId: [DiscoveredDelegatedAccountProtocol]]> {
            try accountsFetchOperation
                .extractNoCancellableResultData()
                .reduce(into: [:]) { $0.merge($1, uniquingKeysWith: { $0 + $1 }) }
        }

        mapOperation.addDependency(accountsFetchOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [accountsFetchOperation]
        )
    }
}
