import BigInt

protocol NPoolsClaimRewardsViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {}

protocol NPoolsClaimRewardsPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func selectAccount()
    func select(claimStrategy: NominationPools.ClaimRewardsStrategy)
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

protocol NPoolsClaimRewardsWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable, FeeRetryable {}
