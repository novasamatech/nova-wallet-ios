import Foundation
import SoraKeystore

struct InAppUpdatesViewFactory {
    static func createView(versions: [Release]) -> InAppUpdatesViewProtocol? {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 10

        let interactor = InAppUpdatesInteractor(
            repository: InAppUpdatesRepository(),
            settings: SettingsManager.shared,
            securityLayerService: SecurityLayerService.shared,
            versions: versions,
            operationQueue: operationQueue
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
