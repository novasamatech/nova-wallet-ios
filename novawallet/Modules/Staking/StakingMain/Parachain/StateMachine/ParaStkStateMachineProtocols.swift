import Foundation

protocol ParaStkStateVisitorProtocol {
    func visit(state: ParachainStaking.InitState)
    func visit(state: ParachainStaking.PendingState)
    func visit(state: ParachainStaking.NoStakingState)
    func visit(state: ParachainStaking.DelegatorState)
}

protocol ParaStkStateProtocol {
    func accept(visitor: ParaStkStateVisitorProtocol)

    func process(account: MetaChainAccountResponse?)
    func process(chainAsset: ChainAsset?)
    func process(balance: AssetBalance?)
    func process(price: PriceData?)
    func process(networkInfo: ParachainStaking.NetworkInfo?)
    func process(collatorsInfo: SelectedRoundCollators?)
    func process(calculatorEngine: ParaStakingRewardCalculatorEngineProtocol?)
    func process(delegatorState: ParachainStaking.Delegator?)
    func process(scheduledRequests: [ParachainStaking.ScheduledRequest]?)
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
