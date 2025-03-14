import Foundation

struct MythosStkClaimRewardsState {
    let details: MythosStakingDetails
    let claimableRewards: MythosStakingClaimableRewards
    let claimStrategy: StakingClaimRewardsStrategy
    let autoCompound: Percent?

    func deriveModel() -> MythosStkClaimRewardsModel? {
        guard claimableRewards.shouldClaim else { return nil }

        guard
            case .restake = claimStrategy,
            (autoCompound ?? 0) == 0,
            claimableRewards.total > 0 else {
            return MythosStkClaimRewardsModel()
        }

        let totalStaked = details.totalStake

        guard totalStaked > 0 else {
            return MythosStkClaimRewardsModel()
        }

        var restakeDistribution = details.stakeDistribution.mapValues { collatorDetail in
            collatorDetail.stake * claimableRewards.total / totalStaked
        }

        let totalRestaked = restakeDistribution.values.reduce(0, +)

        // as we rounding down during stake distribution there might be something remained
        let remainedAmount = claimableRewards.total.subtractOrZero(totalRestaked)

        // add remained amount to the collator with max stake
        if
            remainedAmount > 0,
            let maxCollatorId = details.stakeDistribution.max(
                by: { $0.value.stake < $1.value.stake }
            )?.key {
            let maxColAmount = restakeDistribution[maxCollatorId] ?? 0
            restakeDistribution[maxCollatorId] = maxColAmount + remainedAmount
        }

        // leave collators with non zero restaked amount
        restakeDistribution = restakeDistribution.filter { $0.value > 0 }

        return MythosStkClaimRewardsModel(restakeDistribution: restakeDistribution)
    }
}
