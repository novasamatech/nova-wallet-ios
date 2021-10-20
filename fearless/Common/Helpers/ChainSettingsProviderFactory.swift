import Foundation
import IrohaCrypto
import RobinHood

protocol ChainSettingsProviderFactoryProtocol {
    func createStreambleProvider() -> StreamableProvider<ChainSettingsModel>
}

final class ChainSettingsProviderFactory: ChainSettingsProviderFactoryProtocol {
    let storageFacade: StorageFacadeProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol?

    init(
        storageFacade: StorageFacadeProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.storageFacade = storageFacade
        self.operationManager = operationManager
        self.logger = logger
    }

    func createStreambleProvider() -> StreamableProvider<ChainSettingsModel> {
        let mapper = ChainSettingsMapper()

        let repository: CoreDataRepository<ChainSettingsModel, CDChainSettings> = storageFacade
            .createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { _ in true }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger?.error("Did receive error: \(error)")
            }
        }

        return StreamableProvider<ChainSettingsModel>(
            source: AnyStreamableSource(EmptyStreamableSource()),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )
    }
}
