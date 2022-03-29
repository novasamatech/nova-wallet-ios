import BigInt

protocol TransferConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveNetwork(viewModel: NetworkViewModel)
    func didReceiveSender(viewModel: DisplayAddressViewModel)
    func didReceiveRecepient(viewModel: DisplayAddressViewModel)
    func didReceiveWallet(viewModel: StackCellViewModel)
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
}

protocol TransferConfirmPresenterProtocol: AnyObject {
    func setup()
    func submit()
    func showSenderActions()
    func showRecepientActions()
}

protocol TransferConfirmInteractorInputProtocol: TransferSetupInteractorInputProtocol {
    func submit(amount: BigUInt, recepient: AccountAddress, lastFee: BigUInt?)
}

protocol TransferConfirmInteractorOutputProtocol: TransferSetupInteractorOutputProtocol {
    func didCompleteSubmition()
}

protocol TransferConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    TransferErrorPresentable, AddressOptionsPresentable, FeeRetryable {
    func complete(on view: TransferConfirmViewProtocol?, locale: Locale)
}
