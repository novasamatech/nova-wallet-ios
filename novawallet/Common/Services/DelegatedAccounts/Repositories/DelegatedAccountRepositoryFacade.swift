import Foundation
import Operation_iOS

final class DelegatedAccountsRepositoryFacade {
    let repositoryFactory: (GlobalConfig) -> DelegatedAccountsRepositoryProtocol
    let configProvider: GlobalConfigProviding
    let operationQueue: OperationQueue

    init(
        configProvider: GlobalConfigProviding,
        operationQueue: OperationQueue,
        repositoryFactory: @escaping (GlobalConfig) -> DelegatedAccountsRepositoryProtocol
    ) {
        self.configProvider = configProvider
        self.operationQueue = operationQueue
        self.repositoryFactory = repositoryFactory
    }
}

extension DelegatedAccountsRepositoryFacade: DelegatedAccountsRepositoryProtocol {
    func fetchDelegatedAccountsWrapper(
        for accountIds: Set<AccountId>
    ) -> CompoundOperationWrapper<DelegatedAccountsByDelegateMapping> {
        let configWrapper = configProvider.createConfigWrapper()

        let requestWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [repositoryFactory] in
            let config = try configWrapper.targetOperation.extractNoCancellableResultData()

            let operationFactory = repositoryFactory(config)

            return operationFactory.fetchDelegatedAccountsWrapper(for: accountIds)
        }

        requestWrapper.addDependency(wrapper: configWrapper)

        return requestWrapper.insertingHead(operations: configWrapper.allOperations)
    }
}
