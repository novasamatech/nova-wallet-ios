protocol MythosStkUnstakeConfirmViewProtocol: AnyObject {}

protocol MythosStkUnstakeConfirmPresenterProtocol: AnyObject {
    func setup()
}

protocol MythosStkUnstakeConfirmInteractorInputProtocol: MythosStkUnstakeInteractorInputProtocol {
    func submit(model: MythosStkUnstakeModel)
}

protocol MythosStkUnstakeConfirmInteractorOutputProtocol: MythosStkUnstakeInteractorOutputProtocol {
    func didReceiveSubmissionResult(_ result: Result<ExtrinsicHash, Error>)
}

protocol MythosStkUnstakeConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    AddressOptionsPresentable,
    FeeRetryable,
    ModalAlertPresenting,
    MessageSheetPresentable,
    MythosStakingErrorPresentable,
    ExtrinsicSigningErrorHandling,
    ExtrinsicSubmissionPresenting,
    MythosClaimRewardsPresenting {}
