import Foundation

extension ParachainStaking {
    final class NoStakingState: ParachainStaking.BaseState {
        override func accept(visitor: ParaStkStateVisitorProtocol) {
            visitor.visit(state: self)
        }

        override func process(delegatorState: ParachainStaking.Delegator?) {
            if let delegatorState = delegatorState {
                let delegatorState = ParachainStaking.DelegatorState(
                    stateMachine: stateMachine,
                    commonData: commonData,
                    delegatorState: delegatorState,
                    scheduledRequests: nil,
                    delegations: nil
                )

                stateMachine?.transit(to: delegatorState)
            } else {
                stateMachine?.transit(to: self)
            }
        }
    }
}
