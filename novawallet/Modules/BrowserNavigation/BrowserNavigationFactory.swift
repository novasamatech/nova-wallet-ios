import Foundation
import Operation_iOS
import UIKit

enum BrowserNavigationFactory {
    static func createNavigation() -> BrowserNavigationProtocol? {
        guard let mainAppContainer = findMainContainer() else { return nil }

        let navigationTaskFactory = BrowserNavigationTaskFactory(mainAppContainer: mainAppContainer)

        let presenter = shared

        presenter.browserNavigationTaskFactory = navigationTaskFactory

        return presenter
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

    static var shared: BrowserNavigationPresenter = {
        let interactor = createInteractor()
        let presenter = BrowserNavigationPresenter(interactor: interactor)
        interactor.presenter = presenter

        return presenter
    }()
}
