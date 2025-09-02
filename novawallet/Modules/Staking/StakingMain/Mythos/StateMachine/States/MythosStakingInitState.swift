import Foundation

final class MythosStakingInitState: MythosStakingBaseState {
    override func accept(visitor: MythosStakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }

    override func process(stakingDetailsState: MythosStakingDetailsState) {
        switch stakingDetailsState {
        case let .defined(optDetails):
            if let stakingDetails = optDetails {
                let loadingState = MythosStakingTransitionState(
                    stateMachine: stateMachine,
                    commonData: commonData,
                    stakingDetailsState: .defined(stakingDetails),
                    frozenBalanceState: .defined(nil)
                )

                stateMachine?.transit(to: loadingState)
            } else {
                stateMachine?.transit(to: self)
            }
        case .undefined:
            let loadingState = MythosStakingTransitionState(
                stateMachine: stateMachine,
                commonData: commonData,
                frozenBalanceState: .defined(nil)
            )

            stateMachine?.transit(to: loadingState)
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
