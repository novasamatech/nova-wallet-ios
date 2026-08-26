import Foundation

protocol SubtensorStakingConfirmViewProtocol: CollatorStakingConfirmViewProtocol {
    func didReceiveQuote(viewModel: SubtensorQuotePanelViewModel?)
    func didReceiveSlippage(viewModel: String?)
}

protocol SubtensorStakingConfirmInteractorInputProtocol: SubtensorStakingSubmitInteractorInputProtocol {}

protocol SubtensorStakingConfirmInteractorOutputProtocol: SubtensorStakingSubmitInteractorOutputProtocol {}

protocol SubtensorStakingConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    AddressOptionsPresentable,
    FeeRetryable,
    CommonRetryable,
    ModalAlertPresenting,
    MessageSheetPresentable,
    SubtensorStakingErrorPresentable,
    ExtrinsicSigningErrorHandling,
    ExtrinsicSubmissionPresenting {
    func complete(
        on view: CollatorStakingConfirmViewProtocol?,
        sender: ExtrinsicSenderResolution,
        title: ExtrinsicSubmissionPresentingParams.Title
    )
}
