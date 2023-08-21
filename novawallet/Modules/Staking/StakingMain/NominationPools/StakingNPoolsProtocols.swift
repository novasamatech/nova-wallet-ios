import Foundation
import BigInt

protocol StakingNPoolsInteractorInputProtocol: AnyObject {
    func setup()
    func remakeSubscriptions()
    func retryActiveStake()
    func retryStakingDuration()
}

protocol StakingNPoolsInteractorOutputProtocol: AnyObject {
    func didReceive(totalActiveStake: BigUInt)
    func didReceive(minStake: BigUInt?)
    func didReceive(duration: StakingDuration)
    func didReceive(price: PriceData?)
    func didReceive(error: StakingNPoolsError)
}

protocol StakingNPoolsWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func showStakeMore(from view: StakingMainViewProtocol?)
    func showUnstake(from view: StakingMainViewProtocol?)
    func showRedeem(from view: StakingMainViewProtocol?)
    func showClaimRewards(from view: StakingMainViewProtocol?)
}
