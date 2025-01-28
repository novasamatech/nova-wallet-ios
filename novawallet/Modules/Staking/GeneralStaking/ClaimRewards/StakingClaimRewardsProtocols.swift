import Foundation

protocol StakingGenericRewardsViewProtocol: SCLoadableControllerProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
}

protocol StakingGenericRewardsPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func selectAccount()
}

protocol StakingClaimRewardsViewProtocol: StakingGenericRewardsViewProtocol {
    func didReceiveClaimStrategy(viewModel: StakingClaimRewardsStrategy)
}

protocol StakingClaimRewardsPresenterProtocol: StakingGenericRewardsPresenterProtocol {
    func toggleClaimStrategy()
}
