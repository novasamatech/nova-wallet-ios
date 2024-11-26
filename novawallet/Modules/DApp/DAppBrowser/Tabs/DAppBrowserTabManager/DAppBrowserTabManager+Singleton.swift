import Foundation
import Operation_iOS

extension DAppBrowserTabManager {
    private static let readWriteQueueLabel = "\(String(describing: DAppBrowserTabManager.self)) sync queue"

    static let shared: DAppBrowserTabManager = {
        let mapper = DAppBrowserTabMapper()
        let storageFacade = UserDataStorageFacade.shared

        let coreDataRepository = storageFacade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let renderFilesRepository = WebViewRenderFilesOperationFactory(
            repository: FileRepository(),
            directoryPath: ApplicationConfig.shared.webPageRenderCachePath
        )

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let workingQueue = DispatchQueue(
            label: readWriteQueueLabel,
            qos: .userInitiated,
            attributes: [.concurrent]
        )

        let logger = Logger.shared

        return DAppBrowserTabManager(
            fileRepository: renderFilesRepository,
            tabsSubscriptionFactory: PersistentTabLocalSubscriptionFactory(
                storageFacade: storageFacade,
                operationQueue: operationQueue,
                logger: logger
            ),
            repository: AnyDataProviderRepository(coreDataRepository),
            workingQueue: workingQueue,
            operationQueue: operationQueue,
            logger: logger
        )
    }()
}
