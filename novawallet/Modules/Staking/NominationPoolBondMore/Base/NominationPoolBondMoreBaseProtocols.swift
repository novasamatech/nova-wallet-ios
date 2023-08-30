import BigInt

protocol NominationPoolBondMoreBaseInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for points: BigUInt)
}

protocol NominationPoolBondMoreBaseInteractorOutputProtocol: AnyObject {
    func didReceive(price: PriceData?)
    func didReceive(assetBalance: AssetBalance?)
    func didReceive(fee: BigUInt?)
    func didReceive(error: NominationPoolBondMoreError)

    func didReceive(poolMember: NominationPools.PoolMember?)
    func didReceive(bondedPool: NominationPools.BondedPool?)
    func didReceive(stakingLedger: StakingLedger?)
    func didReceive(claimableRewards: BigUInt?)
    func didReceive(assetBalanceExistance: AssetBalanceExistence?)
}

protocol NominationPoolBondMoreBaseWireframeProtocol: ErrorPresentable, AlertPresentable, CommonRetryable, FeeRetryable, NominationPoolErrorPresentable {}

enum NominationPoolBondMoreError: Error {
    case fetchBalanceFailed(Error)
    case fetchFeeFailed(Error)
    case fetchPriceFailed(Error)
    case subscription(Error, String)
    case claimableRewards(Error)
    case assetExistance(Error)
}
