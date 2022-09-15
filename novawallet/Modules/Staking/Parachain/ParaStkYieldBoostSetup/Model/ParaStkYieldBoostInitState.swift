import Foundation

struct ParaStkYieldBoostInitState {
    let delegator: ParachainStaking.Delegator?
    let delegationIdentities: [AccountId: AccountIdentity]?
    let scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?
    let yieldBoostTasks: [ParaStkYieldBoostState.Task]?
}
