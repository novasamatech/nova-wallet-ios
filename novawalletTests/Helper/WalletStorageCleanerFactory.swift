import Foundation
@testable import novawallet
import Operation_iOS

extension WalletStorageCleanerFactory {
    static func createTestCleaner(
        operationQueue: OperationQueue,
        storageFacade: UserDataStorageTestFacade
    ) -> WalletStorageCleaning {
        let browserStateCleaner = createBrowserStateCleaner(
            operationQueue: operationQueue,
            storageFacade: storageFacade
        )
        let dAppSettingsCleaner = createDAppSettingsCleaner(storageFacade: storageFacade)

        let cleaners = [
            browserStateCleaner,
            dAppSettingsCleaner
        ]

        let mainCleaner = WalletStorageCleaner(cleanersCascade: cleaners)

        return mainCleaner
    }

    private static func createBrowserStateCleaner(
        operationQueue: OperationQueue,
        storageFacade: StorageFacadeProtocol
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

        let browserStateCleaner = RemovedWalletBrowserStateCleaner(
            browserTabManager: tabManager,
            webViewPoolEraser: WebViewPool.shared,
            operationQueue: operationQueue
        )

        return browserStateCleaner
    }

    private static func createDAppSettingsCleaner(storageFacade: StorageFacadeProtocol) -> WalletStorageCleaning {
        let mapper = DAppSettingsMapper()

        let repository = storageFacade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )
        let authorizedDAppRepository = AnyDataProviderRepository(repository)

        let dappSettingsCleaner = RemovedWalletDAppSettingsCleaner(
            authorizedDAppRepository: authorizedDAppRepository
        )

        return dappSettingsCleaner
    }
}
