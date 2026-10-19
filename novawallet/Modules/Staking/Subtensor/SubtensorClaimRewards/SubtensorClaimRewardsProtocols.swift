import Foundation

protocol SubtensorClaimRewardsViewProtocol: StakingGenericRewardsViewProtocol {
    func didReceiveValidator(viewModel: DisplayAddressViewModel)
    func didReceive(viewModel: SubtensorClaimRewardsViewModel)
}

protocol SubtensorClaimRewardsPresenterProtocol: StakingGenericRewardsPresenterProtocol {
    func selectValidator()
}
