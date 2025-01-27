protocol MythosStakingConfirmInteractorInputProtocol: MythosStakingBaseInteractorInputProtocol {
    func submit(model: MythosStakeModel)
}

protocol MythosStakingConfirmInteractorOutputProtocol: MythosStakingBaseInteractorOutputProtocol {
    func didReceiveSubmition(result: Result<String, Error>)
}

protocol MythosStakingConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    AddressOptionsPresentable,
    FeeRetryable,
    ModalAlertPresenting,
    MessageSheetPresentable,
    MythosStakingErrorPresentable,
    ExtrinsicSigningErrorHandling,
    ExtrinsicSubmissionPresenting,
    MythosClaimRewardsPresenting {}
