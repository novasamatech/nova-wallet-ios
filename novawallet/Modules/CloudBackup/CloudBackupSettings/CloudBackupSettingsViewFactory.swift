import Foundation
import SoraFoundation

struct CloudBackupSettingsViewFactory {
    static func createView() -> CloudBackupSettingsViewProtocol? {
        let interactor = CloudBackupSettingsInteractor()
        let wireframe = CloudBackupSettingsWireframe()

        let presenter = CloudBackupSettingsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: CloudBackupSettingsViewModelFactory(),
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = CloudBackupSettingsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
