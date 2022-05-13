import Foundation

protocol StakingParachainInteractorInputProtocol: AnyObject {
    func setup()
}

protocol StakingParachainInteractorOutputProtocol: AnyObject {
    func didReceivePrice(_ price: PriceData?)
    func didReceiveAssetBalance(_ assetBalance: AssetBalance?)
    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?)
    func didReceiveScheduledRequests(_ requests: [ParachainStaking.ScheduledRequest]?)
    func didReceiveSelectedCollators(_ collatorsInfo: SelectedRoundCollators)
    func didReceiveRewardCalculator(_ calculator: ParaStakingRewardCalculatorEngineProtocol)
    func didReceiveNetworkInfo(_ networkInfo: ParachainStaking.NetworkInfo)
    func didReceiveError(_ error: Error)
}
