import Foundation

extension Array where Element == SubtensorStakingPosition {
    func sortedForSubtensorDisplay() -> [SubtensorStakingPosition] {
        sorted { lhs, rhs in
            if (lhs.netuid == SubtensorStakingPallet.rootNetuid) !=
                (rhs.netuid == SubtensorStakingPallet.rootNetuid) {
                return lhs.netuid == SubtensorStakingPallet.rootNetuid
            }

            return lhs.stakeAlpha > rhs.stakeAlpha
        }
    }
}
