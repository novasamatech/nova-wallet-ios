import Foundation

protocol StakingParachainInteractorInputProtocol: AnyObject {
    func setup()
    func fetchScheduledRequests(for collators: [AccountId])
}

protocol StakingParachainInteractorOutputProtocol: AnyObject {
    func didReceiveChainAsset(_ chainAsset: ChainAsset)
    func didReceiveAccount(_ account: MetaChainAccountResponse?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveAssetBalance(_ assetBalance: AssetBalance?)
    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?)
    func didReceiveScheduledRequests(_ requests: [ParachainStaking.DelegatorScheduledRequest]?)
    func didReceiveSelectedCollators(_ collatorsInfo: SelectedRoundCollators)
    func didReceiveRewardCalculator(_ calculator: ParaStakingRewardCalculatorEngineProtocol)
    func didReceiveNetworkInfo(_ networkInfo: ParachainStaking.NetworkInfo)
    func didReceiveStakingDuration(_ stakingDuration: ParachainStakingDuration)
    func didReceiveError(_ error: Error)
}

protocol StakingParachainWireframeProtocol: AnyObject {
    func showRewardDetails(from view: ControllerBackedProtocol?, maxReward: Decimal, avgReward: Decimal)
}
