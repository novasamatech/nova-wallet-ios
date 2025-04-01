import Foundation

protocol MythosStakingBaseInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(with model: MythosStakeTransactionModel)
}

protocol MythosStakingBaseInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveFee(_ fee: ExtrinsicFeeProtocol)
    func didReceiveMinStakeAmount(_ amount: Balance)
    func didReceiveMaxCollatorsPerStaker(_ maxCollatorsPerStaker: UInt32)
    func didReceiveDetails(_ details: MythosStakingDetails?)
    func didReceiveClaimableRewards(_ claimableRewards: MythosStakingClaimableRewards?)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber)
    func didReceiveFrozenBalance(_ frozenBalance: MythosStakingFrozenBalance)
    func didReceiveBaseError(_ error: MythosStakingBaseError)
}

enum MythosStakingBaseError: Error {
    case feeFailed(Error)
}
