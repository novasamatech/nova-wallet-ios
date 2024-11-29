import Foundation
import SoraFoundation
import Operation_iOS

struct DAppBrowserViewFactory {
    static func createChildView(
        for parent: DAppBrowserParentViewProtocol,
        selectedTab: DAppBrowserTab
    ) -> DAppBrowserViewProtocol? {
        let wireframe = DAppBrowserChildWireframe(parentView: parent)

        return createView(
            with: selectedTab,
            wireframe: wireframe
        )
    }

    static func createView(
        selectedTab: DAppBrowserTab
    ) -> DAppBrowserViewProtocol? {
        let wireframe = DAppBrowserWireframe()

        return createView(
            with: selectedTab,
            wireframe: wireframe
        )
    }

    private static func createView(
        with selectedTab: DAppBrowserTab,
        wireframe: DAppBrowserWireframeProtocol
    ) -> DAppBrowserViewProtocol? {
        guard let wallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let localizationManager = LocalizationManager.shared
        let logger = Logger.shared

        let storageFacade = UserDataStorageFacade.shared
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: storageFacade)

        let canDebugDApp = ApplicationConfig.shared.canDebugDApp

        let transports: [DAppBrowserTransportProtocol] = [
            DAppPolkadotExtensionTransport(),
            DAppMetamaskTransport(isDebug: canDebugDApp)
        ]

        let phishingVerifier = PhishingSiteVerifier.createSequentialVerifier()

        let favoritesRepository = accountRepositoryFactory.createFavoriteDAppsRepository()

        let dAppSettingsRepository = accountRepositoryFactory.createAuthorizedDAppsRepository(
            for: wallet.metaId
        )

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let interactor = DAppBrowserInteractor(
            transports: transports,
            selectedTab: selectedTab,
            wallet: wallet,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            securedLayer: SecurityLayerService.shared,
            dAppSettingsRepository: AnyDataProviderRepository(dAppSettingsRepository),
            dAppGlobalSettingsRepository: accountRepositoryFactory.createDAppsGlobalSettingsRepository(),
            dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactory.shared,
            dAppsFavoriteRepository: favoritesRepository,
            operationQueue: operationQueue,
            sequentialPhishingVerifier: phishingVerifier,
            tabManager: DAppBrowserTabManager.shared,
            logger: logger
        )

        let presenter = DAppBrowserPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager,
            logger: logger
        )

        let view = DAppBrowserViewController(
            presenter: presenter,
            localRouter: URLLocalRouter.createWithDeeplinks(),
            webViewPool: WebViewPool.shared,
            deviceOrientationManager: DeviceOrientationManager.shared,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
