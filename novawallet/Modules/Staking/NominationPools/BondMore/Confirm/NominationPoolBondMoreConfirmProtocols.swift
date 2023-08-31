protocol NominationPoolBondMoreConfirmViewProtocol: AnyObject {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveHints(viewModel: [String])
    func didStartLoading()
    func didStopLoading()
}

protocol NominationPoolBondMoreConfirmPresenterProtocol: AnyObject {
    func setup()
    func proceed()
    func selectAccount()
}

protocol NominationPoolBondMoreConfirmInteractorInputProtocol: AnyObject {}

protocol NominationPoolBondMoreConfirmInteractorOutputProtocol: AnyObject {}

protocol NominationPoolBondMoreConfirmWireframeProtocol: AnyObject {}
