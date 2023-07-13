import Foundation
import BigInt

extension ParachainStaking {
    struct NetworkInfo: Equatable {
        let totalStake: BigUInt
        let minStakeForRewards: BigUInt
        let minTechStake: BigUInt
        let maxRewardableDelegators: UInt32
        let activeDelegatorsCount: Int
    }
}
