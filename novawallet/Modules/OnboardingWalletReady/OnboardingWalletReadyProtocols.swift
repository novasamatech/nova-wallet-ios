protocol OnboardingWalletReadyViewProtocol: ControllerBackedProtocol {
    func didReceive(walletName: String)
    func didStartBackupLoading()
    func didStopBackupLoading()
}

protocol OnboardingWalletReadyPresenterProtocol: AnyObject {
    func setup()
    func applyCloudBackup()
    func applyManualBackup()
}

protocol OnboardingWalletReadyInteractorInputProtocol: AnyObject {
    func checkCloudBackupAvailability()
}

protocol OnboardingWalletReadyInteractorOutputProtocol: AnyObject {
    func didReceiveCloudBackupAvailable()
    func didReceive(error: OnboardingWalletReadyInteractorError)
}

protocol OnboardingWalletReadyWireframeProtocol: AlertPresentable, CloudBackupErrorPresentable {
    func showCloudBackup(from view: OnboardingWalletReadyViewProtocol?, walletName: String)
    func showManualBackup(from view: OnboardingWalletReadyViewProtocol?, walletName: String)
}

enum OnboardingWalletReadyInteractorError: Error {
    case cloudBackupNotAvailable
    case notEnoughStorageInCloud
    case timeout
    case internalError(Error)
}
