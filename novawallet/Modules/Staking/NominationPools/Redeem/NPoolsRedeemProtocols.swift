import BigInt

protocol NPoolsRedeemViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
}

protocol NPoolsRedeemPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func selectAccount()
}

protocol NPoolsRedeemInteractorInputProtocol: AnyObject {
    func setup()
    func remakeSubscriptions()
    func estimateFee()
    func submit()
}

protocol NPoolsRedeemInteractorOutputProtocol: AnyObject {
    func didReceive(assetBalance: AssetBalance?)
    func didReceive(poolMember: NominationPools.PoolMember?)
    func didReceive(subPools: NominationPools.SubPools?)
    func didReceive(activeEra: ActiveEraInfo?)
    func didReceive(price: PriceData?)
    func didReceive(fee: BigUInt?)
    func didReceive(submissionResult: Result<String, Error>)
    func didReceive(error: NPoolsRedeemError)
}

protocol NPoolsRedeemWireframeProtocol: ErrorPresentable, AlertPresentable, CommonRetryable, FeeRetryable,
    AddressOptionsPresentable, MessageSheetPresentable,
    NominationPoolErrorPresentable, ExtrinsicSubmissionPresenting {}
