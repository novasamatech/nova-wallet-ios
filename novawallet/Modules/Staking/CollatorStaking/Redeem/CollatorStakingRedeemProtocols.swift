import Foundation

protocol CollatorStakingRedeemViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
}

protocol CollatorStakingRedeemPresenterProtocol: AnyObject {
    func setup()
    func selectAccount()
    func confirm()
}
