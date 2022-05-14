import Foundation

extension ParachainStaking {
    final class PendingState: ParachainStaking.BaseState {
        private(set) var scheduledRequests: [ParachainStaking.ScheduledRequest]

        init(
            stateMachine: ParaStkStateMachineProtocol?,
            commonData: ParachainStaking.CommonData,
            scheduledRequests: [ParachainStaking.ScheduledRequest]
        ) {
            self.scheduledRequests = scheduledRequests

            super.init(stateMachine: stateMachine, commonData: commonData)
        }

        override func accept(visitor: ParaStkStateVisitorProtocol) {
            visitor.visit(state: self)
        }

        override func process(scheduledRequests: [ParachainStaking.ScheduledRequest]?) {
            if let scheduledRequests = scheduledRequests {
                self.scheduledRequests = scheduledRequests

                stateMachine?.transit(to: self)
            } else {
                let noStakingState = ParachainStaking.NoStakingState(
                    stateMachine: stateMachine,
                    commonData: commonData
                )

                stateMachine?.transit(to: noStakingState)
            }
        }

        override func process(delegatorState: ParachainStaking.Delegator?) {
            if let delegatorState = delegatorState {
                let delegatorState = ParachainStaking.DelegatorState(
                    stateMachine: stateMachine,
                    commonData: commonData,
                    delegatorState: delegatorState,
                    scheduledRequests: scheduledRequests
                )

                stateMachine?.transit(to: delegatorState)
            } else {
                stateMachine?.transit(to: self)
            }
        }
    }
}
