import Foundation
import Operation_iOS

extension DAppBrowserTabManager {
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
        let logger = Logger.shared

        let tabsSubscriptionFactory = PersistentTabLocalSubscriptionFactory(
            storageFacade: storageFacade,
            operationQueue: operationQueue,
            logger: logger
        )

        let walletListLocalSubscriptionFactory = WalletListLocalSubscriptionFactory(
            storageFacade: storageFacade,
            operationManager: OperationManagerFacade.sharedManager,
            logger: logger
        )

        let workingQueue = DispatchQueue.global(qos: .userInitiated)

        return DAppBrowserTabManager(
            fileRepository: renderFilesRepository,
            tabsSubscriptionFactory: tabsSubscriptionFactory,
            walletListLocalSubscriptionFactory: walletListLocalSubscriptionFactory,
            repository: AnyDataProviderRepository(coreDataRepository),
            workingQueue: workingQueue,
            operationQueue: operationQueue,
            logger: logger
        )
    }()
}
