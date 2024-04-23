import UIKit

final class OnboardingWalletReadyInteractor {
    weak var presenter: OnboardingWalletReadyInteractorOutputProtocol?

    let factory: CloudBackupServiceFactoryProtocol

    private var storageManager: CloudBackupStorageManaging?

    init(factory: CloudBackupServiceFactoryProtocol) {
        self.factory = factory
    }

    private func handleStorageManager(error: CloudBackupUploadError) {
        switch error {
        case let .internalError(details):
            presenter?.didReceive(error: .internalError(details))
        case .timeout:
            presenter?.didReceive(error: .timeout)
        case .notEnoughSpace:
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
            let url = factory.createFileManager().getBaseUrl() else {
            presenter?.didReceive(error: .cloudBackupNotAvailable)
            return
        }

        storageManager = factory.createStorageManager(for: url)

        storageManager?.checkStorage(
            of: CloudBackup.requiredCloudSize,
            timeoutInterval: 30,
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
