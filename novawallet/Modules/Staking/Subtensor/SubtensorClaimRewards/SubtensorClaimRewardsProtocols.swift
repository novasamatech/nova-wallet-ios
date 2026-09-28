import Foundation

protocol SubtensorClaimRewardsViewProtocol: StakingGenericRewardsViewProtocol {
    func didReceivePending(viewModel: BalanceViewModelProtocol?)
    func didReceiveHints(viewModel: [String])
}

protocol SubtensorClaimRewardsInteractorInputProtocol: SubtensorStakingBaseInteractorInputProtocol {
    func estimateClaimFee(for hotkey: AccountId)
    func submitClaims(for hotkeys: [AccountId])
}

protocol SubtensorClaimRewardsInteractorOutputProtocol: SubtensorStakingBaseInteractorOutputProtocol {
    func didReceiveSubmissionResult(_ result: Result<SubtensorSubmissionModel, Error>)
}

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
