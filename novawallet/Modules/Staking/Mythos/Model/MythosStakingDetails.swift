import Foundation

struct MythosStakingDetails: Equatable {
    struct CollatorDetails: Hashable, Equatable {
        let stake: Balance
        let session: SessionIndex
    }

    let stakeDistribution: [AccountId: CollatorDetails]
    let maybeLastUnstake: MythosStakingPallet.UserStakeUnavailable?

    var totalStake: Balance {
        stakeDistribution.values.reduce(Balance(0)) { $0 + $1.stake }
    }

    var collatorIds: Set<AccountId> {
        Set(stakeDistribution.keys)
    }
}
