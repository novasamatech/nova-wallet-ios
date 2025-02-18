import Foundation

final class MythosStakingInitState: MythosStakingBaseState {
    override func accept(visitor: MythosStakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }

    override func process(stakingDetails: MythosStakingDetails?) {
        if let stakingDetails {
            let transitionState = MythosStakingDelegatorTransitionState(
                stateMachine: stateMachine,
                commonData: commonData,
                stakingDetails: stakingDetails
            )

            stateMachine?.transit(to: transitionState)
        } else {
            stateMachine?.transit(to: self)
        }
    }

    override func process(frozenBalance: MythosStakingFrozenBalance?) {
        if let frozenBalance, frozenBalance.total > 0 {
            let lockedState = MythosStakingLockedState(
                stateMachine: stateMachine,
                commonData: commonData,
                frozenBalance: frozenBalance
            )

            stateMachine?.transit(to: lockedState)
        } else {
            stateMachine?.transit(to: self)
        }
    }
}
