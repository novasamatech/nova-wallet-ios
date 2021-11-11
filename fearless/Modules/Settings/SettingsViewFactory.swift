import UIKit
import SoraFoundation
import SoraKeystore
import IrohaCrypto
import SubstrateSdk

struct SettingsViewFactory {
    static func createView() -> SettingsViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let profileViewModelFactory = SettingsViewModelFactory(iconGenerator: PolkadotIconGenerator())

        let interactor = SettingsInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared
        )

        let wireframe = SettingsWireframe()

        let view = SettingsViewController(nib: R.nib.profileViewController)
        view.iconGenerating = PolkadotIconGenerator()

        let presenter = SettingsPresenter(
            viewModelFactory: profileViewModelFactory,
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
