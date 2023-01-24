import SoraKeystore

protocol InAppUpdatesServiceProtocol: AnyObject {
    var interactor: InAppUpdatesInteractorInputProtocol { get }
}

final class InAppUpdatesService: InAppUpdatesServiceProtocol {
    let interactor: InAppUpdatesInteractorInputProtocol
    static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 10
        return queue
    }()

    init(interactor: InAppUpdatesInteractorInputProtocol) {
        self.interactor = interactor
    }

    static let shared: InAppUpdatesService = {
        let interactor = InAppUpdatesInteractor(
            repository: InAppUpdatesRepository(),
            currentVersion: ApplicationConfig.shared.version,
            settings: SettingsManager.shared,
            securityLayerService: SecurityLayerService.shared,
            operationQueue: queue
        )
        let wireframe = InAppUpdatesWireframe()

        let presenter = InAppUpdatesPresenter(
            interactor: interactor,
            wireframe: wireframe
        )

        let view = InAppUpdatesViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return InAppUpdatesService(interactor: interactor)
    }()
}
