protocol TransferConfirmViewProtocol: ControllerBackedProtocol {
    func didReceiveNetwork(viewModel: NetworkViewModel)
    func didReceiveSender(viewModel: DisplayAddressViewModel)
    func didReceiveRecepient(viewModel: DisplayAddressViewModel)
    func didReceiveWallet(viewModel: StackCellViewModel)
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
}

protocol TransferConfirmPresenterProtocol: AnyObject {
    func setup()
}

protocol TransferConfirmInteractorInputProtocol: TransferSetupInteractorInputProtocol {}

protocol TransferConfirmInteractorOutputProtocol: TransferSetupInteractorOutputProtocol {}

protocol TransferConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    TransferErrorPresentable {}
