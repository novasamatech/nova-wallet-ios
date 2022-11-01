protocol GovernanceUnlockSetupViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: GovernanceUnlocksViewModel)
}

protocol GovernanceUnlockSetupPresenterProtocol: AnyObject {
    func setup()
    func unlock()
}

protocol GovernanceUnlockSetupInteractorInputProtocol: GovernanceUnlockInteractorInputProtocol {}

protocol GovernanceUnlockSetupInteractorOutputProtocol: GovernanceUnlockInteractorOutputProtocol {}

protocol GovernanceUnlockSetupWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {}
