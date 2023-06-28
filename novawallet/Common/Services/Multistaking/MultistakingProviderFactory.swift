import Foundation
import RobinHood

protocol MultistakingProviderFactoryProtocol {
    func createResolvedAccountsProvider() -> StreamableProvider<Multistaking.ResolvedAccount>
}

final class MultistakingProviderFactory {
    let repositoryFactory: MultistakingRepositoryFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        repositoryFactory: MultistakingRepositoryFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.repositoryFactory = repositoryFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension MultistakingProviderFactory: MultistakingProviderFactoryProtocol {
    func createResolvedAccountsProvider() -> StreamableProvider<Multistaking.ResolvedAccount> {
        let repository = repositoryFactory.createResolvedAccountRepository()
        let source = EmptyStreamableSource<Multistaking.ResolvedAccount>()
        let observable = CoreDataContextObservable(
            service: repositoryFactory.storageFacade.databaseService,
            mapper: AnyCoreDataMapper(StakingResolvedAccountMapper()),
            predicate: { _ in true }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Can't start storage observing: \(error)")
            }
        }

        return StreamableProvider(
            source: AnyStreamableSource(source),
            repository: repository,
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }
}
