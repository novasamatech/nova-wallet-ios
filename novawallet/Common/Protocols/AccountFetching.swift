import Foundation
import Operation_iOS

protocol AccountFetching {
    func fetchFirstAccount(
        for accountId: AccountId,
        accountRequest: ChainAccountRequest,
        repositoryFactory: AccountRepositoryFactoryProtocol,
        operationQueue: OperationQueue,
        closure: @escaping (Result<ChainAccountResponse?, Error>) -> Void
    )

    func fetchFirstMetaAccountResponse(
        for accountId: AccountId,
        accountRequest: ChainAccountRequest,
        repositoryFactory: AccountRepositoryFactoryProtocol,
        operationQueue: OperationQueue,
        closure: @escaping (Result<MetaChainAccountResponse?, Error>) -> Void
    )

    func fetchAllMetaAccountChainResponses(
        for accountRequest: ChainAccountRequest,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue,
        closure: @escaping (Result<[MetaAccountChainResponse], Error>) -> Void
    )

    func fetchDisplayAddress(
        for accountIds: [AccountId],
        chain: ChainModel,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue,
        completion: @escaping ((Result<[DisplayAddress], Error>) -> Void)
    ) -> CancellableCall
}

extension AccountFetching {
    func fetchFirstAccount(
        for accountId: AccountId,
        accountRequest: ChainAccountRequest,
        repositoryFactory: AccountRepositoryFactoryProtocol,
        operationQueue: OperationQueue,
        closure: @escaping (Result<ChainAccountResponse?, Error>) -> Void
    ) {
        let repository = repositoryFactory.createAccountRepository(for: accountId)
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let mapOperation = ClosureOperation<ChainAccountResponse?> {
            let metAccounts = try fetchOperation.extractNoCancellableResultData()

            let responses: [ChainAccountResponse] = metAccounts.compactMap { metaAccount in
                guard
                    let accountResponse = metaAccount.fetch(for: accountRequest),
                    accountResponse.accountId == accountId else {
                    return nil
                }

                return accountResponse
            }

            return responses.first
        }

        mapOperation.addDependency(fetchOperation)

        let wrapper = CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main,
            callbackClosure: closure
        )
    }

    func fetchFirstMetaAccountResponse(
        for accountId: AccountId,
        accountRequest: ChainAccountRequest,
        repositoryFactory: AccountRepositoryFactoryProtocol,
        operationQueue: OperationQueue,
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

        let wrapper = CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main,
            callbackClosure: closure
        )
    }

    func fetchAllMetaAccountChainResponses(
        for accountRequest: ChainAccountRequest,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue,
        closure: @escaping (Result<[MetaAccountChainResponse], Error>) -> Void
    ) {
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let mapOperation = ClosureOperation<[MetaAccountChainResponse]> {
            let metaAccounts = try fetchOperation.extractNoCancellableResultData()

            let responses: [MetaAccountChainResponse] = metaAccounts.map { metaAccount in
                let metaAccountResponse = metaAccount.fetchMetaChainAccount(for: accountRequest)
                return MetaAccountChainResponse(
                    metaAccount: metaAccount,
                    chainAccountResponse: metaAccountResponse
                )
            }

            return responses
        }

        mapOperation.addDependency(fetchOperation)

        let wrapper = CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main,
            callbackClosure: closure
        )
    }

    func fetchAllMetaAccountResponses(
        for accountRequest: ChainAccountRequest,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue,
        closure: @escaping (Result<[MetaChainAccountResponse], Error>) -> Void
    ) {
        fetchAllMetaAccountChainResponses(
            for: accountRequest,
            repository: repository,
            operationQueue: operationQueue
        ) { result in
            switch result {
            case let .success(response):
                closure(.success(response.compactMap(\.chainAccountResponse)))
            case let .failure(error):
                closure(.failure(error))
            }
        }
    }

    func fetchDisplayAddress(
        for accountIds: [AccountId],
        chain: ChainModel,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue,
        completion: @escaping ((Result<[DisplayAddress], Error>) -> Void)
    ) -> CancellableCall {
        let allAccountsOperation = repository.fetchAllOperation(
            with: RepositoryFetchOptions()
        )

        let mapOperation = ClosureOperation<[DisplayAddress]> {
            let metaAccounts = try allAccountsOperation.extractNoCancellableResultData()

            return try accountIds.map { accountId in
                let optionAccount = metaAccounts.first { metaAccount in
                    metaAccount.substrateAccountId == accountId ||
                        metaAccount.ethereumAddress == accountId ||
                        metaAccount.chainAccounts.contains { chainAccount in
                            chainAccount.accountId == accountId && chainAccount.chainId == chain.chainId
                        }
                }

                let address = try accountId.toAddress(using: chain.chainFormat)

                if let account = optionAccount {
                    return DisplayAddress(address: address, username: account.name)
                } else {
                    return DisplayAddress(address: address, username: "")
                }
            }
        }

        mapOperation.addDependency(allAccountsOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [allAccountsOperation]
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main,
            callbackClosure: completion
        )

        return wrapper
    }
}
