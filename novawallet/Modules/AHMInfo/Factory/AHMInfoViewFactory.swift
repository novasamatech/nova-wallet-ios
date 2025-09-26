import Foundation
import Foundation_iOS

final class AHMInfoViewFactory {
    static func createView(
        remoteData: AHMRemoteData
    ) -> AHMInfoViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let interactor = AHMInfoInteractor(
            remoteData: remoteData,
            chainRegistry: chainRegistry
        )

        let wireframe = AHMInfoWireframe()

        let viewModelFactory = AHMInfoViewModelFactory()

        let localizationManager = LocalizationManager.shared

        let presenter = AHMInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            remoteData: remoteData,
            localizationManager: localizationManager
        )

        guard let bannersModule = BannersViewFactory.createView(
            domain: remoteData.bannerPath,
            output: presenter,
            inputOwner: presenter,
            locale: localizationManager.selectedLocale
        ) else {
            return nil
        }

        let view = AHMInfoViewController(
            presenter: presenter,
            bannersViewProvider: bannersModule
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
