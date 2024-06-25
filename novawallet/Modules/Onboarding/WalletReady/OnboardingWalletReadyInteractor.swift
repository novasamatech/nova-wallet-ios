import UIKit

final class OnboardingWalletReadyInteractor {
    weak var presenter: OnboardingWalletReadyInteractorOutputProtocol?

    let factory: CloudBackupServiceFactoryProtocol
    let serviceFacade: CloudBackupServiceFacadeProtocol

    init(factory: CloudBackupServiceFactoryProtocol, serviceFacade: CloudBackupServiceFacadeProtocol) {
        self.factory = factory
        self.serviceFacade = serviceFacade
    }
}

extension OnboardingWalletReadyInteractor: OnboardingWalletReadyInteractorInputProtocol {
    func checkCloudBackupAvailability() {
        let availabilityService = factory.createAvailabilityService()
        availabilityService.setup()

        guard case .available = availabilityService.stateObserver.state else {
            presenter?.didReceive(error: .cloudBackupNotAvailable)
            return
        }

        serviceFacade.checkBackupExists(runCompletionIn: .main) { [weak self] result in
            switch result {
            case let .success(isBackupExists):
                if isBackupExists {
                    self?.presenter?.didDetectExistingCloudBackup()
                } else {
                    self?.presenter?.didReceiveCloudBackupAvailable()
                }
            case let .failure(error):
                self?.presenter?.didReceive(error: .internalError(error))
            }
        }
    }
}
