import Foundation
import SoraKeystore
import CommonWallet
import SubstrateSdk

final class MainTabBarInteractor {
    weak var presenter: MainTabBarInteractorOutputProtocol?

    let eventCenter: EventCenterProtocol
    let keystoreImportService: KeystoreImportServiceProtocol
    let serviceCoordinator: ServiceCoordinatorProtocol
    let securedLayer: SecurityLayerServiceProtocol

    deinit {
        stopServices()
    }

    init(
        eventCenter: EventCenterProtocol,
        serviceCoordinator: ServiceCoordinatorProtocol,
        keystoreImportService: KeystoreImportServiceProtocol,
        securedLayer: SecurityLayerServiceProtocol
    ) {
        self.eventCenter = eventCenter
        self.keystoreImportService = keystoreImportService
        self.serviceCoordinator = serviceCoordinator
        self.securedLayer = securedLayer

        startServices()
    }

    private func startServices() {
        serviceCoordinator.setup()
    }

    private func stopServices() {
        serviceCoordinator.throttle()
    }
}

extension MainTabBarInteractor: MainTabBarInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)
        keystoreImportService.add(observer: self)

        if keystoreImportService.definition != nil {
            presenter?.didRequestImportAccount()
        }
    }
}

extension MainTabBarInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        serviceCoordinator.updateOnAccountChange()
    }
}

extension MainTabBarInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from _: KeystoreDefinition?) {
        securedLayer.scheduleExecutionIfAuthorized { [weak self] in
            guard self?.keystoreImportService.definition != nil else {
                return
            }

            self?.presenter?.didRequestImportAccount()
        }
    }
}
