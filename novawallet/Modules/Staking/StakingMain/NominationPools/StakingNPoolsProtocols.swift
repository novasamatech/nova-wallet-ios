import Foundation
import BigInt

protocol StakingNPoolsInteractorInputProtocol: AnyObject {
    func setup()
    func setupTotalRewards(filter: StakingRewardFiltersPeriod)
    func remakeSubscriptions()
    func retryActiveStake()
    func retryStakingDuration()
    func retryActivePools()
    func retryEraCountdown()
    func retryClaimableRewards()
}

protocol StakingNPoolsInteractorOutputProtocol: AnyObject {
    func didReceive(totalActiveStake: BigUInt)
    func didReceive(minStake: BigUInt?)
    func didReceive(activeEra: Staking.ActiveEraInfo?)
    func didReceive(poolLedger: Staking.Ledger?)
    func didReceive(poolNomination: Staking.Nomination?)
    func didReceive(poolMember: NominationPools.PoolMember?)
    func didReceive(bondedPool: NominationPools.BondedPool?)
    func didReceive(subPools: NominationPools.SubPools?)
    func didRecieve(claimableRewards: BigUInt?)
    func didReceive(totalRewards: TotalRewardItem?)
    func didReceive(poolBondedAccountId: AccountId)
    func didReceive(poolMetadata: Data?)
    func didReceive(activePools: Set<NominationPools.PoolId>)
    func didReceive(duration: StakingDuration)
    func didReceive(eraCountdown: EraCountdown)
    func didReceive(price: PriceData?)
    func didReceive(error: StakingNPoolsError)
}

protocol StakingNPoolsWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable {
    func showStakeMore(from view: StakingMainViewProtocol?)
    func showUnstake(from view: StakingMainViewProtocol?)
    func showRedeem(from view: StakingMainViewProtocol?)
    func showClaimRewards(from view: StakingMainViewProtocol?)
}
