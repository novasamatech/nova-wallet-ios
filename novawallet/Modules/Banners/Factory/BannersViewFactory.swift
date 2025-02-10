import Foundation
import Kingfisher
import SoraFoundation
import SoraKeystore

struct BannersViewFactory {
    static func createView(
        domain: Banners.Domain,
        output: BannersModuleOutputProtocol,
        inputOwner: BannersModuleInputOwnerProtocol
    ) -> BannersViewProtocol? {
        let appConfig = ApplicationConfig.shared
        let jsonDataProviderFactory = JsonDataProviderFactory.shared

        let imageManager = KingfisherManager.shared
        let remoteImageProvider = CommonRemoteImageProvider(imageManager: imageManager)
        let imageRetrieveOperationFactory = ImageRetrieveOperationFactory(
            imageManager: imageManager,
            remoteProvider: remoteImageProvider
        )

        let operationManager = OperationManagerFacade.sharedManager

        let bannersFactory = BannersFetchOperationFactory(
            domain: domain,
            bannersContentPath: appConfig.bannersContentPath,
            jsonDataProviderFactory: jsonDataProviderFactory,
            imageRetrieveOperationFactory: imageRetrieveOperationFactory,
            operationManager: operationManager
        )
        let localizationFactory = BannersLocalizationFactory(
            domain: domain,
            bannersContentPath: appConfig.bannersContentPath,
            jsonDataProviderFactory: jsonDataProviderFactory
        )
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let interactor = BannersInteractor(
            domain: domain,
            bannersFactory: bannersFactory,
            localizationFactory: localizationFactory,
            settingsManager: SettingsManager.shared,
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
