import Foundation

protocol ParaStkUnstakeConfirmInteractorInputProtocol: ParaStkBaseUnstakeInteractorInputProtocol,
    PendingExtrinsicInteracting {
    func confirm(for callWrapper: UnstakeCallWrapper)
}

protocol ParaStkUnstakeConfirmInteractorOutputProtocol: ParaStkBaseUnstakeInteractorOutputProtocol {
    func didCompleteExtrinsicSubmission(for result: Result<String, Error>)
}

protocol ParaStkUnstakeConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    ParachainStakingErrorPresentable,
    AddressOptionsPresentable,
    FeeRetryable,
    MessageSheetPresentable, ExtrinsicSigningErrorHandling {
    func complete(on view: CollatorStkUnstakeConfirmViewProtocol?, locale: Locale)
}
