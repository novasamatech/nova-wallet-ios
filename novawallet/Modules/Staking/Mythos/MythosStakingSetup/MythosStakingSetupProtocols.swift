import BigInt

protocol MythosStakingSetupInteractorInputProtocol: MythosStakingBaseInteractorInputProtocol {
    func applyCollator(with accountId: AccountId)
}

protocol MythosStakingSetupInteractorOutputProtocol: MythosStakingBaseInteractorOutputProtocol {
    func didReceiveRewardCalculator(_ calculator: CollatorStakingRewardCalculatorEngineProtocol)
    func didReceiveCandidateInfo(_ info: MythosStakingPallet.CandidateInfo?)
    func didReceiveDelegationIdentities(_ identities: [AccountId: AccountIdentity]?)
    func didReceivePreferredCollator(_ collator: DisplayAddress?)
}

protocol MythosStakingSetupWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CollatorStakingDelegationSelectable,
    MythosStakingErrorPresentable {
    func showConfirmation(
        from view: CollatorStakingSetupViewProtocol?,
        model: MythosStakingConfirmModel
    )

    func showCollatorSelection(
        from view: CollatorStakingSetupViewProtocol?,
        delegate: CollatorStakingSelectDelegate
    )
}
