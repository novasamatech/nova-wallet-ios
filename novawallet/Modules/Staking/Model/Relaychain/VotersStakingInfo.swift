import Foundation
import BigInt

struct VotersStakingInfo {
    let bagsThresholds: [BigUInt]
    let maxElectingVoters: UInt32

    func hasVotersLimit(for votersCount: UInt32) -> Bool {
        votersCount >= maxElectingVoters
    }
}
