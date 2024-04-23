import Foundation
import SoraKeystore
import SoraFoundation

struct CloudBackupCreateViewFactory {
    static func createView(from walletName: String) -> CloudBackupCreateViewProtocol? {
        let interactor = createInteractor(for: walletName)
        let wireframe = CloudBackupCreateWireframe()

        let presenter = CloudBackupCreatePresenter(
            interactor: interactor,
            wireframe: wireframe,
            hintsViewModelFactory: CloudBackPasswordViewModelFactory(),
            passwordValidator: CloudBackupPasswordValidator(),
            localizationManager: LocalizationManager.shared
        )

        let view = CloudBackupCreateViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(for walletName: String) -> CloudBackupCreateInteractor {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let serviceFactory = ICloudBackupServiceFactory(operationQueue: operationQueue)
        let serviceFacade = CloudBackupServiceFacade(
            serviceFactory: serviceFactory,
            operationQueue: operationQueue
        )

        return .init(
            walletName: walletName,
            cloudBackupFacade: serviceFacade,
            walletSettings: SelectedWalletSettings.shared,
            persistentKeystore: Keychain(),
            operationQueue: operationQueue
        )
    }
}
