import BigInt

protocol NPoolsUnstakeConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveHints(viewModel: [String])
}

protocol NPoolsUnstakeConfirmPresenterProtocol: AnyObject {
    func setup()
    func proceed()
    func selectAccount()
}

protocol NPoolsUnstakeConfirmInteractorInputProtocol: NPoolsUnstakeBaseInteractorInputProtocol {
    func submit(unstakingPoints: BigUInt)
}

protocol NPoolsUnstakeConfirmInteractorOutputProtocol: NPoolsUnstakeBaseInteractorOutputProtocol {
    func didReceive(submissionResult: Result<String, Error>)
}

protocol NPoolsUnstakeConfirmWireframeProtocol: NPoolsUnstakeBaseWireframeProtocol, AddressOptionsPresentable,
    MessageSheetPresentable, ExtrinsicSubmissionPresenting {}
