import Foundation

protocol SubtensorUnstakeConfirmViewProtocol: CollatorStkUnstakeConfirmViewProtocol {
    func didReceiveQuote(viewModel: SubtensorQuotePanelViewModel?)
    func didReceiveSlippage(viewModel: String?)
}

protocol SubtensorUnstakeConfirmInteractorInputProtocol: SubtensorStakingSubmitInteractorInputProtocol {}

protocol SubtensorUnstakeConfirmInteractorOutputProtocol: SubtensorStakingSubmitInteractorOutputProtocol {}

protocol SubtensorUnstakeConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    AddressOptionsPresentable,
    FeeRetryable,
    CommonRetryable,
    ModalAlertPresenting,
    MessageSheetPresentable,
    SubtensorStakingErrorPresentable,
    ExtrinsicSigningErrorHandling,
    ExtrinsicSubmissionPresenting {
    func complete(
        on view: CollatorStkUnstakeConfirmViewProtocol?,
        sender: ExtrinsicSenderResolution,
        title: ExtrinsicSubmissionPresentingParams.Title
    )
}
