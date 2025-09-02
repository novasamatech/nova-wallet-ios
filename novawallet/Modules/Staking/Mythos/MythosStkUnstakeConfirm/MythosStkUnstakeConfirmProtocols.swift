protocol MythosStkUnstakeConfirmInteractorInputProtocol: MythosStkUnstakeInteractorInputProtocol {
    func submit(model: MythosStkUnstakeModel)
}

protocol MythosStkUnstakeConfirmInteractorOutputProtocol: MythosStkUnstakeInteractorOutputProtocol {
    func didReceiveSubmissionResult(_ result: Result<ExtrinsicSubmittedModel, Error>)
}

protocol MythosStkUnstakeConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    AddressOptionsPresentable,
    CommonRetryable,
    FeeRetryable,
    ModalAlertPresenting,
    MessageSheetPresentable,
    MythosStakingErrorPresentable,
    ExtrinsicSigningErrorHandling,
    ExtrinsicSubmissionPresenting {}
