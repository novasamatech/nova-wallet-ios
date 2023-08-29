import BigInt

protocol NPoolsClaimRewardsViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: DisplayWalletViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveClaimStrategy(viewModel: NominationPools.ClaimRewardsStrategy)
}

protocol NPoolsClaimRewardsPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func selectAccount()
    func toggleClaimStrategy()
}

protocol NPoolsClaimRewardsInteractorInputProtocol: AnyObject {
    func setup()
    func remakeSubscriptions()
    func estimateFee(for strategy: NominationPools.ClaimRewardsStrategy)
    func submit(for strategy: NominationPools.ClaimRewardsStrategy)
}

protocol NPoolsClaimRewardsInteractorOutputProtocol: AnyObject {
    func didReceive(assetBalance: AssetBalance?)
    func didReceive(claimableRewards: BigUInt?)
    func didReceive(price: PriceData?)
    func didReceive(fee: BigUInt?)
    func didReceive(submissionResult: Result<String, Error>)
    func didReceive(error: NPoolsClaimRewardsError)
}

protocol NPoolsClaimRewardsWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable, FeeRetryable,
    AddressOptionsPresentable, MessageSheetPresentable,
    ExtrinsicSubmissionPresenting, NominationPoolErrorPresentable {}
