import Foundation

protocol SubtensorClaimRewardsViewProtocol: StakingGenericRewardsViewProtocol {
    func didReceiveValidator(viewModel: DisplayAddressViewModel)
    func didReceive(viewModel: SubtensorClaimRewardsViewModel)
}

protocol SubtensorClaimRewardsPresenterProtocol: StakingGenericRewardsPresenterProtocol {
    func selectValidator()
}

protocol SubtensorClaimInteractorInputProtocol: SubtensorStakingBaseInteractorInputProtocol {
    func refreshClaimSnapshot()
}

protocol SubtensorClaimInteractorOutputProtocol: SubtensorStakingBaseInteractorOutputProtocol {
    func didReceiveClaimSnapshot(_ claimable: SubtensorRootClaimable)
    func didFailClaimSnapshot(_ error: Error)
}

protocol SubtensorClaimRewardsWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CommonRetryable, MessageSheetPresentable, SubtensorStakingErrorPresentable, SubtensorClaimErrorPresentable,
    SubtensorInfoSheetPresentable, SubtensorValidatorInfoPresentable, SubtensorOperationResultPresenting {}
