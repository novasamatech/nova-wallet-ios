import Foundation
import SoraFoundation
import SoraKeystore

struct CloudBackupSettingsViewFactory {
    static func createView() -> CloudBackupSettingsViewProtocol? {
        let interactor = createInteractor()

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

    private static func createInteractor() -> CloudBackupSettingsInteractor {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let serviceFactory = ICloudBackupServiceFactory(operationQueue: operationQueue)

        let serviceFacade = CloudBackupServiceFacade(
            serviceFactory: serviceFactory,
            operationQueue: operationQueue
        )

        let interactor = CloudBackupSettingsInteractor(
            cloudBackupSyncMediator: CloudBackupSyncMediatorFacade.sharedMediator,
            cloudBackupServiceFacade: serviceFacade
        )

        return interactor
    }
}
