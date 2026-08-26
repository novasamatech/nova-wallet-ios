import Foundation

protocol SubtensorStakingStateVisitorProtocol {
    func visit(state: SubtensorStakingInitState)
    func visit(state: SubtensorStakingNotStakedState)
    func visit(state: SubtensorStakingStakedState)
}

protocol SubtensorStakingStateProtocol {
    func accept(visitor: SubtensorStakingStateVisitorProtocol)

    func process(account: MetaChainAccountResponse?)
    func process(chainAsset: ChainAsset?)
    func process(balance: AssetBalance?)
    func process(price: PriceData?)
    func process(positionsState: Multistaking.SubtensorStakingState?)
    func process(claimable: SubtensorRootClaimable?)
    func process(delegates: [SubtensorDelegate]?)
    func process(subnetsInfo: SubtensorSubnetsInfo?)
    func process(networkInfo: SubtensorNetworkInfo?)
    func process(totalReward: TotalRewardItem?)
    func process(totalRewardFilter: StakingRewardFiltersPeriod?)
    func process(positionsSyncFailed: Bool)
}

protocol SubtensorStakingStateMachineProtocol: AnyObject {
    var state: SubtensorStakingStateProtocol { get }

    func transit(to state: SubtensorStakingStateProtocol)
}

extension SubtensorStakingStateMachineProtocol {
    func viewState<S: SubtensorStakingStateProtocol, V>(using closure: (S) -> V?) -> V? {
        if let concreteState = state as? S {
            return closure(concreteState)
        } else {
            return nil
        }
    }
}

protocol SubtensorStakingStateMachineDelegate: AnyObject {
    func stateMachineDidChangeState(_ stateMachine: SubtensorStakingStateMachineProtocol)
}
