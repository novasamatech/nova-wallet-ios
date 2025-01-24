import Foundation

struct CollatorStakingDelegator {
    let delegations: [StakingTarget]
}

extension CollatorStakingDelegator {
    init(parachainDelegator: ParachainStaking.Delegator) {
        delegations = parachainDelegator.delegations.map {
            StakingTarget(candidate: $0.owner, amount: $0.amount)
        }
    }
}
