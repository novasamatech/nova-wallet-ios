import Foundation

protocol StakingClaimRewardsViewProtocol: SCLoadableControllerProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveClaimStrategy(viewModel: StakingClaimRewardsViewMode)
}

protocol StakingClaimRewardsPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func selectAccount()
    func toggleClaimStrategy()
}
