import UIKit

final class OnboardingWalletReadyInteractor {
    weak var presenter: OnboardingWalletReadyInteractorOutputProtocol?

    let factory: CloudBackupServiceFactoryProtocol
    let serviceFacade: CloudBackupServiceFacadeProtocol

    private var storageManager: CloudBackupStorageManaging?

    init(factory: CloudBackupServiceFactoryProtocol, serviceFacade: CloudBackupServiceFacadeProtocol) {
        self.factory = factory
        self.serviceFacade = serviceFacade
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

    private func checkEnoughStorage(for url: URL) {
        storageManager = factory.createStorageManager(for: url)

        storageManager?.checkStorage(
            of: CloudBackup.requiredCloudSize,
            timeoutInterval: CloudBackup.backupSaveTimeout,
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

        serviceFacade.checkBackupExists(runCompletionIn: .main) { [weak self] result in
            switch result {
            case let .success(isBackupExists):
                if isBackupExists {
                    self?.presenter?.didDetectExistingCloudBackup()
                } else {
                    self?.checkEnoughStorage(for: url)
                }
            case let .failure(error):
                self?.presenter?.didReceive(error: .internalError(error))
            }
        }
    }
}
