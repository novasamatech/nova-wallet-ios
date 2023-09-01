import BigInt

protocol NPoolsUnstakeBaseInteractorInputProtocol: AnyObject {
    func setup()
    func retrySubscriptions()
    func retryStakingDuration()
    func retryEraCountdown()
    func retryClaimableRewards()
    func retryUnstakeLimits()
    func estimateFee(for points: BigUInt)
}

protocol NPoolsUnstakeBaseInteractorOutputProtocol: AnyObject {
    func didReceive(assetBalance: AssetBalance?)
    func didReceive(poolMember: NominationPools.PoolMember?)
    func didReceive(bondedPool: NominationPools.BondedPool?)
    func didReceive(stakingLedger: StakingLedger?)
    func didReceive(stakingDuration: StakingDuration)
    func didReceive(eraCountdown: EraCountdown)
    func didReceive(claimableRewards: BigUInt?)
    func didReceive(minStake: BigUInt?)
    func didReceive(price: PriceData?)
    func didReceive(unstakingLimits: NominationPools.UnstakeLimits)
    func didReceive(fee: BigUInt?)
    func didReceive(error: NPoolsUnstakeBaseError)
}

protocol NPoolsUnstakeBaseWireframeProtocol: ErrorPresentable, AlertPresentable, CommonRetryable, FeeRetryable,
    NominationPoolErrorPresentable {}
