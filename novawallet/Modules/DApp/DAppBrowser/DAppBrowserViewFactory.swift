import Foundation
import SoraFoundation
import Operation_iOS

struct DAppBrowserViewFactory {
    static func createView(for userQuery: DAppSearchResult) -> DAppBrowserViewProtocol? {
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

        let interactor = DAppBrowserInteractor(
            transports: transports,
            userQuery: userQuery,
            wallet: wallet,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            securedLayer: SecurityLayerService.shared,
            dAppSettingsRepository: AnyDataProviderRepository(dAppSettingsRepository),
            dAppGlobalSettingsRepository: accountRepositoryFactory.createDAppsGlobalSettingsRepository(),
            dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactory.shared,
            dAppsFavoriteRepository: favoritesRepository,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            sequentialPhishingVerifier: phishingVerifier,
            logger: logger
        )

        let wireframe = DAppBrowserWireframe()

        let presenter = DAppBrowserPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager,
            logger: logger
        )

        let view = DAppBrowserViewController(
            presenter: presenter,
            localRouter: URLLocalRouter.createWithDeeplinks(),
            deviceOrientationManager: DeviceOrientationManager.shared,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
