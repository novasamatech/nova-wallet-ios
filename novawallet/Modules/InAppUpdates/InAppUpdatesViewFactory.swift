import Foundation
import SoraKeystore

struct InAppUpdatesViewFactory {
    static func createView() -> InAppUpdatesViewProtocol? {
        let interactor = InAppUpdatesInteractor(
            repository: InAppUpdatesRepository(),
            currentVersion: ApplicationConfig.shared.version,
            settings: SettingsManager.shared,
            securityLayerService: SecurityLayerService.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let wireframe = InAppUpdatesWireframe()

        let presenter = InAppUpdatesPresenter(
            interactor: interactor,
            wireframe: wireframe
        )

        let view = InAppUpdatesViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
