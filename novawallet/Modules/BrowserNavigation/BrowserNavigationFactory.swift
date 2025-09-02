import Foundation
import Operation_iOS
import UIKit

enum BrowserNavigationFactory {
    static func createNavigation(
        for mainContainer: NovaMainAppContainerViewProtocol
    ) -> BrowserNavigationProtocol? {
        let interactor = createInteractor()
        let navigationTaskFactory = BrowserNavigationTaskFactory(mainAppContainer: mainContainer)
        let presenter = BrowserNavigationPresenter(
            interactor: interactor,
            browserNavigationTaskFactory: navigationTaskFactory
        )
        interactor.presenter = presenter

        return presenter
    }

    static func createNavigation() -> BrowserNavigationProtocol? {
        findMainContainer()?.browserNavigation
    }

    private static func createInteractor() -> BrowserNavigationInteractor {
        let appConfig = ApplicationConfig.shared
        let dAppsUrl = appConfig.dAppsListURL
        let dAppProvider: AnySingleValueProvider<DAppList> = JsonDataProviderFactory.shared.getJson(
            for: dAppsUrl
        )

        let logger = Logger.shared

        let favoritesRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createFavoriteDAppsRepository()

        let interactor = BrowserNavigationInteractor(
            walletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            dAppProvider: dAppProvider,
            dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactory.shared,
            dAppsFavoriteRepository: AnyDataProviderRepository(favoritesRepository),
            logger: logger
        )

        return interactor
    }

    private static func findMainContainer() -> NovaMainAppContainerViewProtocol? {
        UIApplication
            .shared
            .windows
            .first { $0.isKeyWindow }?
            .rootViewController as? NovaMainAppContainerViewProtocol
    }
}
