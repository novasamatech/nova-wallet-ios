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

protocol OnboardingWalletReadyInteractorInputProtocol: AnyObject {}

protocol OnboardingWalletReadyInteractorOutputProtocol: AnyObject {}

protocol OnboardingWalletReadyWireframeProtocol: AnyObject {}
