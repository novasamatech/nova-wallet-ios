import Foundation

extension ParachainStaking {
    final class InitState: ParachainStaking.BaseState {
        override func accept(visitor: ParaStkStateVisitorProtocol) {
            visitor.visit(state: self)
        }

        override func process(delegatorState: ParachainStaking.Delegator?) {
            if let delegatorState = delegatorState {
                let delegatorState = ParachainStaking.DelegatorState(
                    stateMachine: stateMachine,
                    commonData: commonData,
                    delegatorState: delegatorState,
                    scheduledRequests: nil
                )

                stateMachine?.transit(to: delegatorState)
            } else {
                let noStakingState = ParachainStaking.NoStakingState(
                    stateMachine: stateMachine,
                    commonData: commonData
                )

                stateMachine?.transit(to: noStakingState)
            }
        }
    }
}
