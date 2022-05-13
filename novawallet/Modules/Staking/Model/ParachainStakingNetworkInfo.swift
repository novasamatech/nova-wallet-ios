import Foundation
import BigInt

extension ParachainStaking {
    struct NetworkInfo {
        let totalStake: BigUInt
        let minStakeForRewards: BigUInt
        let minTechStake: BigUInt
        let activeDelegatorsCount: Int
        let stakingDuration: ParachainStakingDuration
    }
}
