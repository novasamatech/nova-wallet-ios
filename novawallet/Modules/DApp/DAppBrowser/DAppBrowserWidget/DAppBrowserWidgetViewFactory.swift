import Foundation
import SoraFoundation

struct DAppBrowserWidgetViewFactory {
    static func createView() -> DAppBrowserWidgetViewProtocol? {
        let storageFacade = UserDataStorageFacade.shared
        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared

        let walletListLocalSubscriptionFactory = WalletListLocalSubscriptionFactory(
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let updatedWalletCleaner = WalletStorageCleanerFactory.createUpdatedWalletStorageCleaner(
            using: operationQueue
        )
        let removedWalletCleaner = WalletStorageCleanerFactory.createRemovedWalletStorageCleaner(
            using: operationQueue
        )

        let interactor = DAppBrowserWidgetInteractor(
            tabManager: DAppBrowserTabManager.shared,
            walletListLocalSubscriptionFactory: walletListLocalSubscriptionFactory,
            selectedWalletSettings: SelectedWalletSettings.shared,
            removedWalletsCleaner: removedWalletCleaner,
            updatedWalletsCleaner: updatedWalletCleaner,
            operationQueue: operationQueue,
            logger: logger
        )

        let wireframe = DAppBrowserWidgetWireframe()

        let viewModelFactory = DAppBrowserWidgetViewModelFactory(
            dAppIconViewModelFactory: DAppIconViewModelFactory()
        )

        let presenter = DAppBrowserWidgetPresenter(
            interactor: interactor,
            wireframe: wireframe,
            browserTabsViewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let webViewPool = WebViewPool.shared

        let view = DAppBrowserWidgetViewController(
            presenter: presenter,
            webViewPoolEraser: webViewPool
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
