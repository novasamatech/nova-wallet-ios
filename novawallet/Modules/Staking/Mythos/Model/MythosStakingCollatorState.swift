import Foundation

struct MythosStakingCollatorDelegationState {
    let delegatorModel: CollatorStakingDelegator?
    let accountId: AccountId
    let isElected: Bool

    var status: CollatorStakingDelegationStatus {
        guard isElected else {
            return .notElected
        }

        let hasDelegation = delegatorModel?.hasDelegation(to: accountId) ?? false

        return hasDelegation ? .rewarded : .notRewarded
    }
}
