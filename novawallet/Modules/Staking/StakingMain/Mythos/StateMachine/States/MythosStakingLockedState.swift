import Foundation

final class MythosStakingLockedState: MythosStakingBaseState {
    private(set) var frozenBalance: MythosStakingFrozenBalance

    init(
        stateMachine: MythosStakingStateMachineProtocol?,
        commonData: MythosStakingCommonData,
        frozenBalance: MythosStakingFrozenBalance
    ) {
        self.frozenBalance = frozenBalance

        super.init(stateMachine: stateMachine, commonData: commonData)
    }

    override func accept(visitor: MythosStakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }

    override func process(stakingDetailsState: MythosStakingDetailsState) {
        switch stakingDetailsState {
        case let .defined(optDetails):
            if let stakingDetails = optDetails {
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
        case .undefined:
            let loadingState = MythosStakingTransitionState(
                stateMachine: stateMachine,
                commonData: commonData,
                frozenBalanceState: .defined(frozenBalance)
            )

            stateMachine?.transit(to: loadingState)
        }
    }

    override func process(frozenBalance: MythosStakingFrozenBalance?) {
        if let frozenBalance, frozenBalance.total > 0 {
            self.frozenBalance = frozenBalance

            stateMachine?.transit(to: self)
        } else {
            let initState = MythosStakingInitState(
                stateMachine: stateMachine,
                commonData: commonData
            )

            stateMachine?.transit(to: initState)
        }
    }
}
