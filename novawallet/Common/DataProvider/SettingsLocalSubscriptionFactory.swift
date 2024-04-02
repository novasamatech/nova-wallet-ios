import Foundation
import RobinHood
import SubstrateSdk

protocol SettingsLocalSubscriptionFactoryProtocol {
    func getPushSettingsProvider() -> StreamableProvider<Web3Alert.LocalSettings>?
    func getTopicsProvider() -> StreamableProvider<PushNotification.TopicSettings>?
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
    func getPushSettingsProvider() -> StreamableProvider<Web3Alert.LocalSettings>? {
        let cacheKey = "push-settings"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<Web3Alert.LocalSettings> {
            return provider
        }

        let mapper = AnyCoreDataMapper(Web3AlertSettingsMapper())
        let repository: CoreDataRepository<Web3Alert.LocalSettings, CDUserSingleValue> =
            storageFacade.createRepository(
                filter: .pushSettings,
                sortDescriptors: [],
                mapper: mapper
            )

        let source = EmptyStreamableSource<Web3Alert.LocalSettings>()

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

    func getTopicsProvider() -> StreamableProvider<PushNotification.TopicSettings>? {
        let cacheKey = "topics-settings"

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<PushNotification.TopicSettings> {
            return provider
        }

        let mapper = AnyCoreDataMapper(Web3TopicSettingsMapper())
        let repository: CoreDataRepository<PushNotification.TopicSettings, CDUserSingleValue> =
            storageFacade.createRepository(
                filter: .topicSettings,
                sortDescriptors: [],
                mapper: mapper
            )

        let source = EmptyStreamableSource<PushNotification.TopicSettings>()

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
