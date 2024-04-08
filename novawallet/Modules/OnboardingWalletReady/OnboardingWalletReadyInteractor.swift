import UIKit

final class OnboardingWalletReadyInteractor {
    weak var presenter: OnboardingWalletReadyInteractorOutputProtocol?

    let factory: CloudBackupServiceFactoryProtocol

    init(factory: CloudBackupServiceFactoryProtocol) {
        self.factory = factory
    }

    private func handleStorageManager(error: CloudBackupStorageManagingError) {
        switch error {
        case let .internalError(details):
            presenter?.didReceive(error: .internalError(details))
        case .notEnoughStorage:
            presenter?.didReceive(error: .notEnoughStorageInCloud)
        }
    }
}

extension OnboardingWalletReadyInteractor: OnboardingWalletReadyInteractorInputProtocol {
    func checkCloudBackupAvailability() {
        let availabilityService = factory.createAvailabilityService()
        availabilityService.setup()

        guard
            case .available = availabilityService.stateObserver.state,
            let url = factory.baseUrl else {
            presenter?.didReceive(error: .cloudBackupNotAvailable)
            return
        }

        let storageManager = factory.createStorageManager(for: url)

        storageManager.checkStorage(
            of: CloudBackup.requiredCloudSize,
            runningIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.didReceiveCloudBackupAvailable()
            case let .failure(error):
                self?.handleStorageManager(error: error)
            }
        }
    }
}
