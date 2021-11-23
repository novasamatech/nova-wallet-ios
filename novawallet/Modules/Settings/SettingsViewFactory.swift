import UIKit
import SoraFoundation
import SoraKeystore
import IrohaCrypto
import SubstrateSdk

struct SettingsViewFactory {
    static func createView() -> SettingsViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let profileViewModelFactory = SettingsViewModelFactory(iconGenerator: NovaIconGenerator())

        let interactor = SettingsInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared
        )

        let wireframe = SettingsWireframe()

        let view = SettingsViewController()

        let presenter = SettingsPresenter(
            viewModelFactory: profileViewModelFactory,
            config: ApplicationConfig.shared,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        view.presenter = presenter
        presenter.view = view
        interactor.presenter = presenter

        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager

        return view
    }
}
