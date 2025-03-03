import Foundation

protocol CollatorStkUnstakeConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveCollator(viewModel: DisplayAddressViewModel)
    func didReceiveHints(viewModel: [String])
}

protocol CollatorStkUnstakeConfirmPresenterProtocol {
    func setup()
    func selectAccount()
    func selectCollator()
    func confirm()
}
