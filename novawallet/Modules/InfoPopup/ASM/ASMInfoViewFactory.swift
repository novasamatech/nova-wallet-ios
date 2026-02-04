import Foundation
import Foundation_iOS
import Keystore_iOS

struct ASMInfoPopupViewFactory {
    static func createView(info: ASMRemoteData) -> InfoPopupViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let interactor = ASMInfoPopupInteractor(
            settingsManager: SettingsManager.shared
        )

        let wireframe = InfoPopupWireframe()
        let viewModelFactory = ASMInfoPopupViewModelFactory()

        let presenter = ASMInfoPopupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            learnMoreURL: info.wikiURL,
            mainAction: .url(info.destinationLinkData.universalLink),
            skipAction: .custom {},
            localizationManager: localizationManager
        )

        guard let bannersModule = BannersViewFactory.createView(
            domain: .appStoreMigration,
            output: presenter,
            inputOwner: presenter,
            locale: localizationManager.selectedLocale
        ) else {
            return nil
        }

        let view = InfoPopupViewController(
            presenter: presenter,
            bannersViewProvider: bannersModule,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
