import Foundation

protocol SubtensorClaimRewardsViewProtocol: StakingGenericRewardsViewProtocol {
    func didReceiveValidator(viewModel: DisplayAddressViewModel)
    func didReceive(viewModel: SubtensorClaimRewardsViewModel)
}

protocol SubtensorClaimRewardsPresenterProtocol: StakingGenericRewardsPresenterProtocol {
    func selectValidator()
}

protocol SubtensorClaimRewardsInteractorInputProtocol: SubtensorBaseInteractorInputProtocol {
    func refreshPendingClaims(for claimable: [SubtensorRootClaimPreview]?)
}

protocol SubtensorClaimRewardsInteractorOutputProtocol: SubtensorBaseInteractorOutputProtocol {
    func didReceive(pendingClaimHotkeys: Set<AccountId>)
}
