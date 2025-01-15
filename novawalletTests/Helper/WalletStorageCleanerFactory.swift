import Foundation
@testable import novawallet
import Operation_iOS

extension WalletStorageCleanerFactory {
    static func createTestCleaner(
        operationQueue: OperationQueue,
        storageFacade: UserDataStorageTestFacade
    ) -> WalletStorageCleaning {
        let mapper = DAppBrowserTabMapper()

        let coreDataRepository = storageFacade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let renderFilesRepository = WebViewRenderFilesOperationFactory(
            repository: FileRepository(),
            directoryPath: ApplicationConfig.shared.webPageRenderCachePath
        )

        let logger = Logger.shared

        let tabsSubscriptionFactory = PersistentTabLocalSubscriptionFactory(
            storageFacade: storageFacade,
            operationQueue: operationQueue,
            logger: logger
        )

        let walletListLocalSubscriptionFactory = WalletListLocalSubscriptionFactory(
            storageFacade: storageFacade,
            operationManager: OperationManager(operationQueue: operationQueue),
            logger: logger
        )

        let tabManager = DAppBrowserTabManager(
            fileRepository: renderFilesRepository,
            tabsSubscriptionFactory: tabsSubscriptionFactory,
            walletListLocalSubscriptionFactory: walletListLocalSubscriptionFactory,
            repository: AnyDataProviderRepository(coreDataRepository),
            operationQueue: operationQueue,
            logger: logger
        )
        
        let walletStorageCleaner = WalletBrowserStateCleaner(
            browserTabManager: tabManager,
            webViewPoolEraser: WebViewPool.shared,
            operationQueue: operationQueue
        )
        
        return walletStorageCleaner
    }
}
