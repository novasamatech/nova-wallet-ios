import Foundation

protocol ParaStkStateVisitorProtocol {
    func visit(state: ParachainStaking.InitState)
    func visit(state: ParachainStaking.DelegatorState)
}

protocol ParaStkStateProtocol {
    func accept(visitor: ParaStkStateVisitorProtocol)

    func process(account: MetaChainAccountResponse?)
    func process(chainAsset: ChainAsset?)
    func process(balance: AssetBalance?)
    func process(price: PriceData?)
    func process(networkInfo: ParachainStaking.NetworkInfo?)
    func process(stakingDuration: ParachainStakingDuration?)
    func process(collatorsInfo: SelectedRoundCollators?)
    func process(calculatorEngine: CollatorStakingRewardCalculatorEngineProtocol?)
    func process(delegatorState: ParachainStaking.Delegator?)
    func process(delegations: [ParachainStkCollatorSelectionInfo]?)
    func process(scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?)
    func process(blockNumber: BlockNumber?)
    func process(roundInfo: ParachainStaking.RoundInfo?)
    func process(totalReward: TotalRewardItem?)
    func process(yieldBoostState: ParaStkYieldBoostState?)
    func process(totalRewardFilter: StakingRewardFiltersPeriod?)
}

protocol ParaStkStateMachineProtocol: AnyObject {
    var state: ParaStkStateProtocol { get }

    func transit(to state: ParaStkStateProtocol)
}

extension ParaStkStateMachineProtocol {
    func viewState<S: ParaStkStateProtocol, V>(using closure: (S) -> V?) -> V? {
        if let concreteState = state as? S {
            return closure(concreteState)
        } else {
            return nil
        }
    }
}

protocol ParaStkStateMachineDelegate: AnyObject {
    func stateMachineDidChangeState(_ stateMachine: ParaStkStateMachineProtocol)
}
