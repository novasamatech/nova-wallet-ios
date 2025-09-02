import BigInt

protocol NPoolsRedeemViewProtocol: SCLoadableControllerProtocol {
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
    func retryExistentialDeposit()
    func estimateFee(needsMigration: Bool)
    func submit(needsMigration: Bool)
}

protocol NPoolsRedeemInteractorOutputProtocol: AnyObject {
    func didReceive(assetBalance: AssetBalance?)
    func didReceive(poolMember: NominationPools.PoolMember?)
    func didReceive(subPools: NominationPools.SubPools?)
    func didReceive(activeEra: ActiveEraInfo?)
    func didReceive(price: PriceData?)
    func didReceive(existentialDeposit: BigUInt?)
    func didReceive(fee: ExtrinsicFeeProtocol)
    func didReceive(submissionResult: Result<ExtrinsicSubmittedModel, Error>)
    func didReceive(needsMigration: Bool)
    func didReceive(error: NPoolsRedeemError)
}

protocol NPoolsRedeemWireframeProtocol: ErrorPresentable, AlertPresentable, CommonRetryable, FeeRetryable,
    AddressOptionsPresentable, MessageSheetPresentable,
    NominationPoolErrorPresentable, ExtrinsicSubmissionPresenting, ExtrinsicSigningErrorHandling {}
