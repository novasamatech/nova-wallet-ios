import Foundation

extension ParachainStaking {
    final class DelegatorState: BaseState {
        private(set) var delegatorState: ParachainStaking.Delegator
        private(set) var scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?
        private(set) var delegations: [ParachainStkCollatorSelectionInfo]?

        init(
            stateMachine: ParaStkStateMachineProtocol?,
            commonData: ParachainStaking.CommonData,
            delegatorState: ParachainStaking.Delegator,
            scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?,
            delegations: [ParachainStkCollatorSelectionInfo]?
        ) {
            self.delegatorState = delegatorState
            self.scheduledRequests = scheduledRequests
            self.delegations = delegations

            super.init(stateMachine: stateMachine, commonData: commonData)
        }

        override func accept(visitor: ParaStkStateVisitorProtocol) {
            visitor.visit(state: self)
        }

        override func process(delegatorState: ParachainStaking.Delegator?) {
            if let delegatorState = delegatorState {
                self.delegatorState = delegatorState

                stateMachine?.transit(to: self)
            } else {
                let noStakingState = ParachainStaking.InitState(
                    stateMachine: stateMachine,
                    commonData: commonData
                )

                stateMachine?.transit(to: noStakingState)
            }
        }

        override func process(delegations: [ParachainStkCollatorSelectionInfo]?) {
            self.delegations = delegations

            stateMachine?.transit(to: self)
        }

        override func process(scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?) {
            self.scheduledRequests = scheduledRequests

            stateMachine?.transit(to: self)
        }
    }
}
