import BigInt

protocol NPoolsUnstakeConfirmViewProtocol: NPoolsUnstakeBaseViewProtocol {
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
    func submit(unstakingPoints: BigUInt, needsMigration: Bool)
}

protocol NPoolsUnstakeConfirmInteractorOutputProtocol: NPoolsUnstakeBaseInteractorOutputProtocol {
    func didReceive(submissionResult: Result<ExtrinsicSubmittedModel, Error>)
}

protocol NPoolsUnstakeConfirmWireframeProtocol: NPoolsUnstakeBaseWireframeProtocol, AddressOptionsPresentable,
    MessageSheetPresentable, ExtrinsicSubmissionPresenting, ExtrinsicSigningErrorHandling {}
