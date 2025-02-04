protocol MythosStkClaimRewardsInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee()
    func submit()
}

protocol MythosStkClaimRewardsInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveClaimableRewards(_ claimableRewards: MythosStakingClaimableRewards)
    func didReceiveFeeResult(_ result: Result<ExtrinsicFeeProtocol, Error>)
    func didReceiveSubmissionResult(_ result: Result<String, Error>)
}

protocol MythosStkClaimRewardsWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable, FeeRetryable,
    AddressOptionsPresentable,
    MythosStakingErrorPresentable,
    MessageSheetPresentable,
    ExtrinsicSubmissionPresenting, ExtrinsicSigningErrorHandling {}
