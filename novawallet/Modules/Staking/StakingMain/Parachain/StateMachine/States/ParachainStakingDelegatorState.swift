import Foundation

extension ParachainStaking {
    final class DelegatorState: BaseState {
        let delegator: ParachainStaking.Delegator
        private var scheduledRequests: [ParachainStaking.ScheduledRequest]?

        init(
            stateMachine: ParaStkStateMachineProtocol?,
            commonData: ParachainStaking.CommonData,
            delegator: ParachainStaking.Delegator,
            scheduledRequests: [ParachainStaking.ScheduledRequest]?
        ) {
            self.delegator = delegator
            self.scheduledRequests = scheduledRequests

            super.init(stateMachine: stateMachine, commonData: commonData)
        }
    }
}
