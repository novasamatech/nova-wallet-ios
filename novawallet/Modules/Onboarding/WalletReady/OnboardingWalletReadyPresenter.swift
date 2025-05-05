import Foundation
import Foundation_iOS

final class OnboardingWalletReadyPresenter {
    weak var view: OnboardingWalletReadyViewProtocol?
    let wireframe: OnboardingWalletReadyWireframeProtocol
    let interactor: OnboardingWalletReadyInteractorInputProtocol

    let walletName: String
    let logger: LoggerProtocol
    let localizationManager: LocalizationManagerProtocol

    init(
        interactor: OnboardingWalletReadyInteractorInputProtocol,
        wireframe: OnboardingWalletReadyWireframeProtocol,
        walletName: String,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.walletName = walletName
        self.localizationManager = localizationManager
        self.logger = logger
    }
}

extension OnboardingWalletReadyPresenter: OnboardingWalletReadyPresenterProtocol {
    func setup() {
        view?.didReceive(walletName: walletName)
    }

    func applyCloudBackup() {
        view?.didStartBackupLoading()
        interactor.checkCloudBackupAvailability()
    }

    func applyManualBackup() {
        wireframe.showManualBackup(from: view, walletName: walletName)
    }
}

extension OnboardingWalletReadyPresenter: OnboardingWalletReadyInteractorOutputProtocol {
    func didReceiveCloudBackupAvailable() {
        wireframe.showCloudBackup(from: view, walletName: walletName)
        view?.didStopBackupLoading()
    }

    func didDetectExistingCloudBackup() {
        wireframe.showExistingBackup(from: view) { [weak self] in
            self?.wireframe.showRecoverBackup(from: self?.view)
        }

        view?.didStopBackupLoading()
    }

    func didReceive(error: OnboardingWalletReadyInteractorError) {
        logger.error("Did receive error: \(error)")

        guard let view else {
            return
        }

        view.didStopBackupLoading()

        switch error {
        case .cloudBackupNotAvailable:
            wireframe.presentCloudBackupUnavailable(
                from: view,
                locale: localizationManager.selectedLocale
            )
        case .internalError, .timeout:
            wireframe.presentNoCloudConnection(from: view, locale: localizationManager.selectedLocale)
        }
    }
}
