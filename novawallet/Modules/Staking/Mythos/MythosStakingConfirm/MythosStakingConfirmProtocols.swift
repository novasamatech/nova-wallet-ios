import Foundation

protocol MythosStakingConfirmInteractorInputProtocol: MythosStakingBaseInteractorInputProtocol {
    func submit(model: MythosStakeModel)
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
    ExtrinsicSubmissionPresenting,
    MythosClaimRewardsPresenting {
    func complete(on view: CollatorStakingConfirmViewProtocol?, locale: Locale)
}
