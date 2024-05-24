import Foundation
import SoraFoundation
import SoraKeystore

struct CloudBackupSettingsViewFactory {
    static func createView(
        with serviceCoordinator: ServiceCoordinatorProtocol
    ) -> CloudBackupSettingsViewProtocol? {
        let interactor = createInteractor(with: serviceCoordinator)
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

    private static func createInteractor(
        with serviceCoordinator: ServiceCoordinatorProtocol
    ) -> CloudBackupSettingsInteractor {
        CloudBackupSettingsInteractor(cloudBackupSyncFacade: serviceCoordinator.cloudBackupSyncFacade)
    }
}
