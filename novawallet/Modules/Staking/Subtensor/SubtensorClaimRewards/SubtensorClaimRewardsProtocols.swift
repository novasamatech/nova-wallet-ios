import Foundation

protocol SubtensorClaimRewardsViewProtocol: StakingGenericRewardsViewProtocol {
    func didReceivePending(viewModel: BalanceViewModelProtocol?)
    func didReceiveHints(viewModel: [String])
}

protocol SubtensorClaimRewardsInteractorInputProtocol: SubtensorStakingBaseInteractorInputProtocol {
    func submitClaims(for hotkeys: [AccountId])
}

protocol SubtensorClaimRewardsInteractorOutputProtocol: SubtensorStakingSubmitInteractorOutputProtocol {}

protocol SubtensorClaimRewardsWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable, FeeRetryable,
    AddressOptionsPresentable,
    ModalAlertPresenting,
    MessageSheetPresentable,
    SubtensorStakingErrorPresentable,
    ExtrinsicSubmissionPresenting, ExtrinsicSigningErrorHandling {
    func complete(
        on view: StakingGenericRewardsViewProtocol?,
        sender: ExtrinsicSenderResolution,
        title: ExtrinsicSubmissionPresentingParams.Title
    )
}
