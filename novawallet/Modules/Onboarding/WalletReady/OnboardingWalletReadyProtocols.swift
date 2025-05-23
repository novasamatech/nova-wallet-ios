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
    func didDetectExistingCloudBackup()
    func didReceive(error: OnboardingWalletReadyInteractorError)
}

protocol OnboardingWalletReadyWireframeProtocol: AlertPresentable, CloudBackupErrorPresentable {
    func showCloudBackup(from view: OnboardingWalletReadyViewProtocol?, walletName: String)
    func showManualBackup(from view: OnboardingWalletReadyViewProtocol?, walletName: String)
    func showRecoverBackup(from view: OnboardingWalletReadyViewProtocol?)

    func showExistingBackup(
        from view: OnboardingWalletReadyViewProtocol?,
        recoverClosure: @escaping () -> Void
    )
}

enum OnboardingWalletReadyInteractorError: Error {
    case cloudBackupNotAvailable
    case timeout
    case internalError(Error)
}
