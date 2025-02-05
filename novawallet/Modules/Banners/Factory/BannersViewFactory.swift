import Foundation
import SoraFoundation

struct BannersViewFactory {
    static func createView(
        domain: Banners.Domain,
        output: BannersModuleOutputProtocol,
        inputOwner: BannersModuleInputOwnerProtocol
    ) -> BannersViewProtocol? {
        let appConfig = ApplicationConfig.shared
        let jsonDataProviderFactory = JsonDataProviderFactory.shared

        let bannersFactory = BannersFetchOperationFactory(
            domain: domain,
            bannersContentPath: appConfig.bannersContentPath,
            jsonDataProviderFactory: jsonDataProviderFactory
        )
        let localizationFactory = BannersLocalizationFactory(
            domain: domain,
            bannersContentPath: appConfig.bannersContentPath,
            jsonDataProviderFactory: jsonDataProviderFactory
        )
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let interactor = BannersInteractor(
            bannersFactory: bannersFactory,
            localizationFactory: localizationFactory,
            operationQueue: operationQueue
        )
        let wireframe = BannersWireframe()

        let viewModelFactory = BannerViewModelFactory()

        let presenter = BannersPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = BannersViewController(presenter: presenter)

        presenter.view = view
        presenter.moduleOutput = output
        interactor.presenter = presenter

        inputOwner.bannersModule = presenter

        return view
    }
}
