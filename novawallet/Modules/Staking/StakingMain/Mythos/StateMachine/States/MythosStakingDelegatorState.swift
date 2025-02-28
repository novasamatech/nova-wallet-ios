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

    override func process(stakingDetailsState: MythosStakingDetailsState) {
        switch stakingDetailsState {
        case let .defined(optDetails):
            if let stakingDetails = optDetails {
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
            let transitionState = MythosStakingTransitionState(
                stateMachine: stateMachine,
                commonData: commonData,
                stakingDetailsState: .defined(stakingDetails),
                frozenBalanceState: .defined(nil)
            )

            stateMachine?.transit(to: transitionState)
        }
    }
}
