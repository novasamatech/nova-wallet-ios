import Foundation

protocol ParaStkUnstakeConfirmInteractorInputProtocol: ParaStkBaseUnstakeInteractorInputProtocol,
    PendingExtrinsicInteracting {
    func confirm(for callWrapper: UnstakeCallWrapper)
}

protocol ParaStkUnstakeConfirmInteractorOutputProtocol: ParaStkBaseUnstakeInteractorOutputProtocol {
    func didCompleteExtrinsicSubmission(for result: Result<ExtrinsicSubmittedModel, Error>)
}

protocol ParaStkUnstakeConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    ParachainStakingErrorPresentable,
    AddressOptionsPresentable,
    FeeRetryable,
    MessageSheetPresentable, ExtrinsicSigningErrorHandling,
    ModalAlertPresenting, ExtrinsicSubmissionPresenting {}
