import Foundation

extension Staking {
    static func getAvailableAmountToStake(
        from free: Decimal,
        bonded: Decimal,
        isStakingMigratedToHolds: Bool
    ) -> Decimal {
        if isStakingMigratedToHolds {
            // Staked amount is counted in reserved - free is already reduced by reserved amount
            return free
        } else {
            // Staked amount is counted in frozen - we should substrate staked amount from free
            return free >= bonded ? free - bonded : 0
        }
    }
}
