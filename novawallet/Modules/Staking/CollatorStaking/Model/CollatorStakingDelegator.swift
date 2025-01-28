import Foundation

struct CollatorStakingDelegator {
    let delegations: [StakingTarget]

    func hasDelegation(to candidate: AccountId) -> Bool {
        delegations.contains { $0.candidate == candidate }
    }
}

extension CollatorStakingDelegator {
    init(parachainDelegator: ParachainStaking.Delegator) {
        delegations = parachainDelegator.delegations.map {
            StakingTarget(candidate: $0.owner, amount: $0.amount)
        }
    }

    init(mythosDelegator: MythosStakingDetails) {
        delegations = mythosDelegator.stakeDistribution.map { keyValue in
            StakingTarget(candidate: keyValue.key, amount: keyValue.value.stake)
        }
    }
}
