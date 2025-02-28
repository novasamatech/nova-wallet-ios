import Foundation

protocol MythosStkUnstakeInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for model: MythosStkUnstakeModel)
    func retryStakingDuration()
}

protocol MythosStkUnstakeInteractorOutputProtocol: AnyObject {
    func didReceiveBalance(_ assetBalance: AssetBalance?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveStakingDetails(_ details: MythosStakingDetails?)
    func didReceiveClaimableRewards(_ rewards: MythosStakingClaimableRewards?)
    func didReceiveMaxUnstakingCollators(_ maxUnstakingCollators: UInt32)
    func didReceiveReleaseQueue(_ releaseQueue: MythosStakingPallet.ReleaseQueue?)
    func didReceiveStakingDuration(_ duration: MythosStakingDuration)
    func didReceiveFee(_ fee: ExtrinsicFeeProtocol)
    func didReceiveBaseError(_ error: MythosStkUnstakeInteractorError)
}

enum MythosStkUnstakeInteractorError: Error {
    case stakingDurationFailed(Error)
    case feeFailed(Error)
}
