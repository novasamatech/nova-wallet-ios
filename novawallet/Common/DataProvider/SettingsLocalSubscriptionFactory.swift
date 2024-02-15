import Foundation
import RobinHood
import SubstrateSdk

protocol SettingsLocalSubscriptionFactoryProtocol {
    func getPushSettingsProvider() -> StreamableProvider<LocalPushSettings>?
}

final class SettingsLocalSubscriptionFactory: BaseLocalSubscriptionFactory {
    let storageFacade: StorageFacadeProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private lazy var operationManager = OperationManager(operationQueue: operationQueue)

    static let shared = SettingsLocalSubscriptionFactory(
        storageFacade: UserDataStorageFacade.shared,
        operationQueue: OperationManagerFacade.sharedDefaultQueue,
        logger: Logger.shared
    )

    init(
        storageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.storageFacade = storageFacade
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension SettingsLocalSubscriptionFactory: SettingsLocalSubscriptionFactoryProtocol {
    func getPushSettingsProvider() -> StreamableProvider<LocalPushSettings>? {
        let cacheKey = "push-settings"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<LocalPushSettings> {
            return provider
        }

        let mapper = AnyCoreDataMapper(Web3AlertSettingsMapper())
        let repository: CoreDataRepository<LocalPushSettings, CDUserSingleValue> =
            storageFacade.createRepository(mapper: mapper)

        let source = EmptyStreamableSource<LocalPushSettings>()

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: mapper,
            predicate: { _ in true }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Can't start storage observing: \(error)")
            }
        }

        let provider = StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )

        saveProvider(provider, for: cacheKey)

        return provider
    }
}
