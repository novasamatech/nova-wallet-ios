import UIKit
import SoraFoundation
import SoraKeystore
import IrohaCrypto
import SubstrateSdk

struct SettingsViewFactory {
    static func createView() -> SettingsViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let profileViewModelFactory = SettingsViewModelFactory(iconGenerator: PolkadotIconGenerator())

        let view = SettingsViewController(nib: R.nib.profileViewController)
        view.iconGenerating = PolkadotIconGenerator()

        let presenter = SettingsPresenter(viewModelFactory: profileViewModelFactory)

        let interactor = SettingsInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared
        )

        let wireframe = SettingsWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager
        presenter.logger = Logger.shared

        return view
    }
}
