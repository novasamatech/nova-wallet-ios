protocol MythosStkUnstakeSetupViewProtocol: ControllerBackedProtocol {}

protocol MythosStkUnstakeSetupPresenterProtocol: AnyObject {
    func setup()
}

protocol MythosStkUnstakeSetupInteractorInputProtocol: MythosStkUnstakeInteractorInputProtocol {}

protocol MythosStkUnstakeSetupInteractorOutputProtocol: MythosStkUnstakeInteractorOutputProtocol {
    func didReceiveDelegationIdentities(_ identities: [AccountId: AccountIdentity]?)
}

protocol MythosStkUnstakeSetupWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable, FeeRetryable,
    MythosStakingErrorPresentable {}
