protocol ParaStkStakeConfirmViewProtocol: ControllerBackedProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveCollator(viewModel: DisplayAddressViewModel)
}

protocol ParaStkStakeConfirmPresenterProtocol: AnyObject {
    func setup()
    func selectAccount()
    func selectCollator()
    func confirm()
}

protocol ParaStkStakeConfirmInteractorInputProtocol: AnyObject {}

protocol ParaStkStakeConfirmInteractorOutputProtocol: AnyObject {}

protocol ParaStkStakeConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    ParachainStakingErrorPresentable,
    AddressOptionsPresentable,
    FeeRetryable {}
