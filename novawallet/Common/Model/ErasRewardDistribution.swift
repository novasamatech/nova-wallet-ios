import Foundation
import BigInt

struct ErasRewardDistribution {
    let totalValidatorRewardByEra: [Staking.EraIndex: BigUInt]
    let validatorPointsDistributionByEra: [Staking.EraIndex: Staking.EraRewardPoints]
}
