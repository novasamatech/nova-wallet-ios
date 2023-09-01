import BigInt

protocol NominationPoolBondMoreConfirmViewProtocol: NominationPoolBondMoreBaseViewProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didStartLoading()
    func didStopLoading()
}

protocol NominationPoolBondMoreConfirmPresenterProtocol: AnyObject {
    func setup()
    func proceed()
    func selectAccount()
}

protocol NominationPoolBondMoreConfirmInteractorInputProtocol: NominationPoolBondMoreBaseInteractorInputProtocol {
    func submit(amount: BigUInt)
}

protocol NominationPoolBondMoreConfirmInteractorOutputProtocol: NominationPoolBondMoreBaseInteractorOutputProtocol {
    func didReceive(submissionResult: SubmitExtrinsicResult)
}

protocol NominationPoolBondMoreConfirmWireframeProtocol: NominationPoolBondMoreBaseWireframeProtocol,
    AddressOptionsPresentable, MessageSheetPresentable, ExtrinsicSubmissionPresenting {}
