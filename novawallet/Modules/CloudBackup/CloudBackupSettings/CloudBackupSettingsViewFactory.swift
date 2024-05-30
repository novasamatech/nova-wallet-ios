import Foundation
import SoraFoundation
import SoraKeystore

struct CloudBackupSettingsViewFactory {
    static func createView() -> CloudBackupSettingsViewProtocol? {
        let interactor = CloudBackupSettingsInteractor(
            cloudBackupSyncMediator: CloudBackupSyncMediatorFacade.sharedMediator
        )

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
