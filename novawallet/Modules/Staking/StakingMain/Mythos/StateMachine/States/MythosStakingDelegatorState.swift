import Foundation

final class MythosStakingDelegatorState: MythosStakingBaseState {
    private(set) var frozenBalance: MythosStakingFrozenBalance
    private(set) var stakingDetails: MythosStakingDetails

    init(
        stateMachine: MythosStakingStateMachineProtocol?,
        commonData: MythosStakingCommonData,
        frozenBalance: MythosStakingFrozenBalance,
        stakingDetails: MythosStakingDetails
    ) {
        self.frozenBalance = frozenBalance
        self.stakingDetails = stakingDetails

        super.init(stateMachine: stateMachine, commonData: commonData)
    }

    override func accept(visitor: MythosStakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }

    override func process(stakingDetails: MythosStakingDetails?) {
        if let stakingDetails {
            self.stakingDetails = stakingDetails

            stateMachine?.transit(to: self)
        } else if frozenBalance.total > 0 {
            let lockedStaked = MythosStakingLockedState(
                stateMachine: stateMachine,
                commonData: commonData,
                frozenBalance: frozenBalance
            )

            stateMachine?.transit(to: lockedStaked)
        } else {
            let initState = MythosStakingInitState(
                stateMachine: stateMachine,
                commonData: commonData
            )

            stateMachine?.transit(to: initState)
        }
    }

    override func process(frozenBalance: MythosStakingFrozenBalance?) {
        if let frozenBalance, frozenBalance.total > 0 {
            self.frozenBalance = frozenBalance

            stateMachine?.transit(to: self)
        } else {
            let transitionState = MythosStakingDelegatorTransitionState(
                stateMachine: stateMachine,
                commonData: commonData,
                stakingDetails: stakingDetails
            )

            stateMachine?.transit(to: transitionState)
        }
    }
}
