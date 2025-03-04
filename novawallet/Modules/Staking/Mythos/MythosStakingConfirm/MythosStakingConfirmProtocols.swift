import Foundation

protocol MythosStakingConfirmInteractorInputProtocol: MythosStakingBaseInteractorInputProtocol {
    func submit(model: MythosStakeTransactionModel)
}

protocol MythosStakingConfirmInteractorOutputProtocol: MythosStakingBaseInteractorOutputProtocol {
    func didReceiveSubmissionResult(_ result: Result<String, Error>)
}

protocol MythosStakingConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    AddressOptionsPresentable,
    FeeRetryable,
    ModalAlertPresenting,
    MessageSheetPresentable,
    MythosStakingErrorPresentable,
    ExtrinsicSigningErrorHandling,
    ExtrinsicSubmissionPresenting {
    func complete(on view: CollatorStakingConfirmViewProtocol?, locale: Locale)
}
