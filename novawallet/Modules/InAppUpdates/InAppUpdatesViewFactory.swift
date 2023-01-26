import Foundation
import SoraFoundation
import SoraKeystore

struct InAppUpdatesViewFactory {
    static func createView(versions: [Release]) -> InAppUpdatesViewProtocol? {
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 10

        let urlProvider = InAppUpdatesUrlProvider(applicationConfig: ApplicationConfig.shared)
        let interactor = InAppUpdatesInteractor(
            repository: InAppUpdatesRepository(urlProvider: urlProvider),
            settings: SettingsManager.shared,
            securityLayerService: SecurityLayerService.shared,
            versions: versions,
            operationQueue: operationQueue
        )

        let wireframe = InAppUpdatesWireframe()
        let localizationManager = LocalizationManager.shared

        let presenter = InAppUpdatesPresenter(
            interactor: interactor,
            localizationManager: localizationManager,
            wireframe: wireframe
        )

        let view = InAppUpdatesViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
