protocol GovernanceUnlockSetupViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: GovernanceUnlocksViewModel)
    func didTickClaim(states: [GovernanceUnlocksViewModel.ClaimState])
}

protocol GovernanceUnlockSetupPresenterProtocol: AnyObject {
    func setup()
    func unlock()
}

protocol GovernanceUnlockSetupInteractorInputProtocol: GovernanceUnlockInteractorInputProtocol {}

protocol GovernanceUnlockSetupInteractorOutputProtocol: GovernanceUnlockInteractorOutputProtocol {}

protocol GovernanceUnlockSetupWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func showConfirm(from view: GovernanceUnlockSetupViewProtocol?, initData: GovernanceUnlockConfirmInitData)
}
