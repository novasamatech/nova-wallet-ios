import Foundation
import RobinHood

protocol AccountFetching {
    func fetchAccount(
        for address: AccountAddress,
        from repository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<AccountItem?, Error>) -> Void
    )

    func fetchAllAccounts(
        from repository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<[AccountItem], Error>) -> Void
    )

    func fetchFirstAccount(
        for accountId: AccountId,
        accountRequest: ChainAccountRequest,
        repositoryFactory: AccountRepositoryFactoryProtocol,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<AccountItem?, Error>) -> Void
    )
}

extension AccountFetching {
    func fetchAccount(
        for address: AccountAddress,
        from repository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<AccountItem?, Error>) -> Void
    ) {
        let operation = repository.fetchOperation(by: address, options: RepositoryFetchOptions())

        operation.completionBlock = {
            DispatchQueue.main.async {
                if let result = operation.result {
                    closure(result)
                } else {
                    closure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func fetchAllAccounts(
        from repository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<[AccountItem], Error>) -> Void
    ) {
        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operation.completionBlock = {
            DispatchQueue.main.async {
                if let result = operation.result {
                    closure(result)
                } else {
                    closure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func fetchFirstAccount(
        for accountId: AccountId,
        accountRequest: ChainAccountRequest,
        repositoryFactory: AccountRepositoryFactoryProtocol,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<AccountItem?, Error>) -> Void
    ) {
        let repository = repositoryFactory.createAccountRepository(for: accountId)
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let mapOperation = ClosureOperation<AccountItem?> {
            let metAccounts = try fetchOperation.extractNoCancellableResultData()

            let responses: [ChainAccountResponse] = metAccounts.compactMap { metaAccount in
                guard
                    let accountResponse = metaAccount.fetch(for: accountRequest),
                    accountResponse.accountId == accountId else {
                    return nil
                }

                return accountResponse
            }

            return try responses.first?.toAccountItem()
        }

        mapOperation.addDependency(fetchOperation)

        mapOperation.completionBlock = {
            DispatchQueue.main.async {
                if let result = mapOperation.result {
                    closure(result)
                } else {
                    closure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: [fetchOperation, mapOperation], in: .transient)
    }

    func fetchFirstMetaAccountResponse(
        for accountId: AccountId,
        accountRequest: ChainAccountRequest,
        repositoryFactory: AccountRepositoryFactoryProtocol,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<MetaChainAccountResponse?, Error>) -> Void
    ) {
        let repository = repositoryFactory.createAccountRepository(for: accountId)
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let mapOperation = ClosureOperation<MetaChainAccountResponse?> {
            let metAccounts = try fetchOperation.extractNoCancellableResultData()

            let responses: [MetaChainAccountResponse] = metAccounts.compactMap { metaAccount in
                guard
                    let metaAccountResponse = metaAccount.fetchMetaChainAccount(for: accountRequest),
                    metaAccountResponse.chainAccount.accountId == accountId else {
                    return nil
                }

                return metaAccountResponse
            }

            return responses.first
        }

        mapOperation.addDependency(fetchOperation)

        mapOperation.completionBlock = {
            DispatchQueue.main.async {
                if let result = mapOperation.result {
                    closure(result)
                } else {
                    closure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: [fetchOperation, mapOperation], in: .transient)
    }

    func fetchAllMetaAccountResponses(
        for accountRequest: ChainAccountRequest,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<[MetaChainAccountResponse], Error>) -> Void
    ) {
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let mapOperation = ClosureOperation<[MetaChainAccountResponse]> {
            let metAccounts = try fetchOperation.extractNoCancellableResultData()

            let responses: [MetaChainAccountResponse] = metAccounts.compactMap { metaAccount in
                guard let metaAccountResponse = metaAccount.fetchMetaChainAccount(for: accountRequest) else {
                    return nil
                }

                return metaAccountResponse
            }

            return responses
        }

        mapOperation.addDependency(fetchOperation)

        mapOperation.completionBlock = {
            DispatchQueue.main.async {
                if let result = mapOperation.result {
                    closure(result)
                } else {
                    closure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: [fetchOperation, mapOperation], in: .transient)
    }
}
