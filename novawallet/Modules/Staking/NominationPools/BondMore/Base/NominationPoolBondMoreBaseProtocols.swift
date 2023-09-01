import BigInt

protocol NominationPoolBondMoreBaseViewProtocol: ControllerBackedProtocol {
    func didReceiveHints(viewModel: [String])
}

protocol NominationPoolBondMoreBaseInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for amount: BigUInt)
    func retrySubscriptions()
    func retryClaimableRewards()
    func retryAssetExistance()
}

protocol NominationPoolBondMoreBaseInteractorOutputProtocol: AnyObject {
    func didReceive(price: PriceData?)
    func didReceive(assetBalance: AssetBalance?)
    func didReceive(fee: BigUInt?)
    func didReceive(error: NominationPoolBondMoreError)
    func didReceive(poolMember: NominationPools.PoolMember?)
    func didReceive(bondedPool: NominationPools.BondedPool?)
    func didReceive(claimableRewards: BigUInt?)
    func didReceive(assetBalanceExistance: AssetBalanceExistence?)
}

protocol NominationPoolBondMoreBaseWireframeProtocol: ErrorPresentable, AlertPresentable, CommonRetryable,
    FeeRetryable, NominationPoolErrorPresentable {}

enum NominationPoolBondMoreError: Error {
    case fetchFeeFailed(Error)
    case subscription(Error, String)
    case claimableRewards(Error)
    case assetExistance(Error)
}
