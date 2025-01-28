import BigInt

protocol NPoolsClaimRewardsInteractorInputProtocol: AnyObject {
    func setup()
    func remakeSubscriptions()
    func retryExistentialDeposit()
    func estimateFee(for strategy: NominationPools.ClaimRewardsStrategy, needsMigration: Bool)
    func submit(for strategy: NominationPools.ClaimRewardsStrategy, needsMigration: Bool)
}

protocol NPoolsClaimRewardsInteractorOutputProtocol: AnyObject {
    func didReceive(assetBalance: AssetBalance?)
    func didReceive(claimableRewards: BigUInt?)
    func didReceive(existentialDeposit: BigUInt?)
    func didReceive(price: PriceData?)
    func didReceive(fee: ExtrinsicFeeProtocol)
    func didReceive(submissionResult: Result<String, Error>)
    func didReceive(needsMigration: Bool)
    func didReceive(error: NPoolsClaimRewardsError)
}

protocol NPoolsClaimRewardsWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable, FeeRetryable,
    AddressOptionsPresentable, MessageSheetPresentable,
    ExtrinsicSubmissionPresenting, NominationPoolErrorPresentable, ExtrinsicSigningErrorHandling {}
