import Foundation

protocol MythosStakingStateVisitorProtocol {
    func visit(state: MythosStakingInitState)
    func visit(state: MythosStakingLockedState)
    func visit(state: MythosStakingDelegatorTransitionState)
    func visit(state: MythosStakingDelegatorState)
}

protocol MythosStakingStateProtocol {
    func accept(visitor: MythosStakingStateVisitorProtocol)

    func process(account: MetaChainAccountResponse?)
    func process(chainAsset: ChainAsset?)
    func process(balance: AssetBalance?)
    func process(price: PriceData?)
    func process(collatorsInfo: MythosSessionCollators?)
    func process(stakingDetails: MythosStakingDetails?)
    func process(frozenBalance: MythosStakingFrozenBalance?)
    func process(totalReward: TotalRewardItem?)
    func process(totalRewardFilter: StakingRewardFiltersPeriod?)
    func process(claimableRewards: MythosStakingClaimableRewards?)
    func process(releaseQueue: MythosStakingPallet.ReleaseQueue?)
    func process(blockNumber: BlockNumber)
    func process(blockTime: BlockTime)
}

protocol MythosStakingStateMachineProtocol: AnyObject {
    var state: MythosStakingStateProtocol { get }

    func transit(to state: MythosStakingStateProtocol)
}

extension MythosStakingStateMachineProtocol {
    func viewState<S: MythosStakingStateProtocol, V>(using closure: (S) -> V?) -> V? {
        if let concreteState = state as? S {
            return closure(concreteState)
        } else {
            return nil
        }
    }
}

protocol MythosStakingStateMachineDelegate: AnyObject {
    func stateMachineDidChangeState(_ stateMachine: MythosStakingStateMachineProtocol)
}
