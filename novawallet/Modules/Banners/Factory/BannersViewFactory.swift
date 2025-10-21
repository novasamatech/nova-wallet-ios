import Foundation
import Kingfisher
import Foundation_iOS
import Keystore_iOS

struct BannersViewFactory {
    static func createView(
        domain: Banners.Domain,
        output: BannersModuleOutputProtocol,
        inputOwner: BannersModuleInputOwnerProtocol,
        locale: Locale
    ) -> BannersViewProtocol? {
        let appConfig = ApplicationConfig.shared

        let imageManager = KingfisherManager.shared
        let remoteImageProvider = CommonRemoteImageProvider(imageManager: imageManager)
        let imageRetrieveOperationFactory = ImageRetrieveOperationFactory(
            imageManager: imageManager,
            remoteProvider: remoteImageProvider
        )

        let operationManager = OperationManagerFacade.sharedManager

        let fetchOperationFactory = BaseFetchOperationFactory()

        let bannersFactory = BannersFetchOperationFactory(
            domain: domain,
            bannersContentPath: appConfig.bannersContentPath,
            fetchOperationFactory: fetchOperationFactory,
            imageRetrieveOperationFactory: imageRetrieveOperationFactory,
            operationManager: operationManager
        )
        let textHeightOperationFactory = TextHeightOperationFactory()
        let localizationFactory = BannersLocalizationFactory(
            domain: domain,
            bannersContentPath: appConfig.bannersContentPath,
            fetchOperationFactory: fetchOperationFactory,
            textHeightOperationFactory: textHeightOperationFactory,
            operationManager: operationManager
        )
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let interactor = BannersInteractor(
            bannersFactory: bannersFactory,
            localizationFactory: localizationFactory,
            settingsManager: SettingsManager.shared,
            operationQueue: operationQueue,
            logger: Logger.shared
        )
        let wireframe = BannersWireframe()

        let viewModelFactory = BannerViewModelFactory()

        let presenter = BannersPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            locale: locale,
            closeActionAvailable: closeFeatureAvailability(for: domain)
        )

        let view = BannersViewController(presenter: presenter)

        presenter.view = view
        presenter.moduleOutput = output
        interactor.presenter = presenter

        inputOwner.bannersModule = presenter

        return view
    }

    private static func closeFeatureAvailability(for domain: Banners.Domain) -> Bool {
        switch domain {
        case .dApps, .ahmKusama, .ahmPolkadot:
            false
        case .assets:
            true
        }
    }
}
