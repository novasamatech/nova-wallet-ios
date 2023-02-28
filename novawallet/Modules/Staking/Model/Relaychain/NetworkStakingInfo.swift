import Foundation
import BigInt

struct NetworkStakingInfo {
    let totalStake: BigUInt
    let minStakeAmongActiveNominators: BigUInt
    let minimalBalance: BigUInt
    let activeNominatorsCount: Int
    let lockUpPeriod: UInt32
    let stakingDuration: StakingDuration
    let votersInfo: VotersStakingInfo?
}

extension NetworkStakingInfo {
    func findBagThreshold(for stake: BigUInt) -> BigUInt? {
        votersInfo?.bagsThresholds.first { stake <= $0 }
    }

    func findNextBagMinStake(for stake: BigUInt) -> BigUInt? {
        guard let threshold = findBagThreshold(for: stake) else {
            return nil
        }

        return threshold + 1
    }

    func calculateTechnicalMinStake(given minNominatorBond: BigUInt?) -> BigUInt {
        max(minNominatorBond ?? minimalBalance, minimalBalance)
    }

    func calculateMinimumStake(given minNominatorBond: BigUInt?, votersCount: UInt32?) -> BigUInt {
        let techMinStake = calculateTechnicalMinStake(given: minNominatorBond)

        guard let votersCount = votersCount, votersInfo?.hasVotersLimit(for: votersCount) == true else {
            return techMinStake
        }

        guard let minStake = findNextBagMinStake(for: minStakeAmongActiveNominators) else {
            return max(minStakeAmongActiveNominators, techMinStake)
        }

        return max(minStake, techMinStake)
    }
}
