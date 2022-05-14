import Foundation

extension ParachainStaking {
    final class DelegatorState: BaseState {
        private var delegatorState: ParachainStaking.Delegator
        private var scheduledRequests: [ParachainStaking.ScheduledRequest]?

        init(
            stateMachine: ParaStkStateMachineProtocol?,
            commonData: ParachainStaking.CommonData,
            delegatorState: ParachainStaking.Delegator,
            scheduledRequests: [ParachainStaking.ScheduledRequest]?
        ) {
            self.delegatorState = delegatorState
            self.scheduledRequests = scheduledRequests

            super.init(stateMachine: stateMachine, commonData: commonData)
        }

        override func process(delegatorState: ParachainStaking.Delegator?) {
            if let delegatorState = delegatorState {
                self.delegatorState = delegatorState

                stateMachine?.transit(to: self)
            } else if let scheduledRequests = scheduledRequests {
                let pendingState = ParachainStaking.PendingState(
                    stateMachine: stateMachine,
                    commonData: commonData,
                    scheduledRequests: scheduledRequests
                )

                stateMachine?.transit(to: pendingState)
            } else {
                let noStakingState = ParachainStaking.NoStakingState(
                    stateMachine: stateMachine,
                    commonData: commonData
                )

                stateMachine?.transit(to: noStakingState)
            }
        }

        override func process(scheduledRequests: [ParachainStaking.ScheduledRequest]?) {
            self.scheduledRequests = scheduledRequests

            stateMachine?.transit(to: self)
        }
    }
}
