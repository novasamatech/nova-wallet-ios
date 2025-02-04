import Foundation

final class MythosStakingDelegatorTransitionState: MythosStakingBaseState {
    private(set) var stakingDetails: MythosStakingDetails

    init(
        stateMachine: MythosStakingStateMachineProtocol?,
        commonData: MythosStakingCommonData,
        stakingDetails: MythosStakingDetails
    ) {
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
            let delegatorState = MythosStakingDelegatorState(
                stateMachine: stateMachine,
                commonData: commonData,
                frozenBalance: frozenBalance,
                stakingDetails: stakingDetails
            )

            stateMachine?.transit(to: delegatorState)
        } else {
            stateMachine?.transit(to: self)
        }
    }
}
