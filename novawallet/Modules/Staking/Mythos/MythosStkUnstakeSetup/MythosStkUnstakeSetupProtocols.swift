protocol MythosStkUnstakeSetupInteractorInputProtocol: MythosStkUnstakeInteractorInputProtocol {}

protocol MythosStkUnstakeSetupInteractorOutputProtocol: MythosStkUnstakeInteractorOutputProtocol {
    func didReceiveDelegationIdentities(_ identities: [AccountId: AccountIdentity]?)
}

protocol MythosStkUnstakeSetupWireframeProtocol: AlertPresentable, ErrorPresentable,
    CollatorStakingDelegationSelectable,
    CommonRetryable, FeeRetryable,
    MythosStakingErrorPresentable {
    func showConfirm(
        from view: CollatorStkFullUnstakeSetupViewProtocol?,
        collator: DisplayAddress
    )
}
