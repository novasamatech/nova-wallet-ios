import Foundation
import Foundation_iOS
import Keystore_iOS

final class AHMInfoViewFactory {
    static func createView(
        info: AHMRemoteData
    ) -> AHMInfoViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let interactor = AHMInfoInteractor(
            info: info,
            chainRegistry: chainRegistry,
            settingsManager: SettingsManager.shared
        )

        let wireframe = AHMInfoWireframe()

        let viewModelFactory = AHMInfoViewModelFactory()

        let localizationManager = LocalizationManager.shared

        let presenter = AHMInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            info: info,
            localizationManager: localizationManager
        )

        guard let bannersModule = BannersViewFactory.createView(
            domain: info.bannerPath,
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
