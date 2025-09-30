import BigInt

protocol NPoolsUnstakeBaseViewProtocol: SCLoadableControllerProtocol {}

protocol NPoolsUnstakeBaseInteractorInputProtocol: AnyObject {
    func setup()
    func retrySubscriptions()
    func retryStakingDuration()
    func retryEraCountdown()
    func retryClaimableRewards()
    func retryUnstakeLimits()
    func retryExistentialDeposit()
    func estimateFee(for points: BigUInt, needsMigration: Bool)
}

protocol NPoolsUnstakeBaseInteractorOutputProtocol: AnyObject {
    func didReceive(assetBalance: AssetBalance?)
    func didReceive(poolMember: NominationPools.PoolMember?)
    func didReceive(bondedPool: NominationPools.BondedPool?)
    func didReceive(stakingLedger: Staking.Ledger?)
    func didReceive(stakingDuration: StakingDuration)
    func didReceive(eraCountdown: EraCountdown)
    func didReceive(claimableRewards: BigUInt?)
    func didReceive(minStake: BigUInt?)
    func didReceive(existentialDeposit: BigUInt?)
    func didReceive(price: PriceData?)
    func didReceive(unstakingLimits: NominationPools.UnstakeLimits)
    func didReceive(fee: ExtrinsicFeeProtocol)
    func didReceive(error: NPoolsUnstakeBaseError)
    func didReceive(needsMigration: Bool)
}

protocol NPoolsUnstakeBaseWireframeProtocol: ErrorPresentable, AlertPresentable, CommonRetryable, FeeRetryable,
    NominationPoolErrorPresentable {}
