import Foundation

struct MythosStkClaimRewardsModel {
    let restakeDistribution: [AccountId: Balance]?

    init(restakeDistribution: [AccountId: Balance]? = nil) {
        self.restakeDistribution = restakeDistribution
    }
}

extension MythosStkClaimRewardsModel {
    struct Restake {
        let lock: MythosStakingPallet.LockCall
        let stake: MythosStakingPallet.StakeCall
    }

    func getRestake() -> Restake? {
        guard let restakeDistribution, !restakeDistribution.isEmpty else {
            return nil
        }

        let totalToLock = restakeDistribution.values.reduce(0, +)

        guard totalToLock > 0 else {
            return nil
        }

        let lockCall = MythosStakingPallet.LockCall(amount: totalToLock)

        let stakeTargets = restakeDistribution.map {
            MythosStakingPallet.StakeTarget(candidate: $0.key, stake: $0.value)
        }

        let stakeCall = MythosStakingPallet.StakeCall(targets: stakeTargets)

        return Restake(lock: lockCall, stake: stakeCall)
    }
}
