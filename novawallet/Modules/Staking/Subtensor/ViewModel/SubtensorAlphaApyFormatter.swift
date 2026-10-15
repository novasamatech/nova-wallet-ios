import Foundation

enum SubtensorAlphaApyFormatter {
    static func annualRate(for hotkey: AccountId, in yields: SubtensorAlphaYields?) -> Decimal? {
        guard let yields, yields.stamp.freshness == .fresh else {
            return nil
        }

        return yields.yields[hotkey]?.annualRate
    }

    static func stakeWeightedRate(
        of positions: [SubtensorStakingPosition],
        in yields: SubtensorAlphaYields?
    ) -> Decimal? {
        let weighted = positions.compactMap { position -> (rate: Decimal, stake: Decimal)? in
            guard
                let rate = annualRate(for: position.hotkey, in: yields),
                let stake = Decimal.fromSubstrateAmount(position.stakeAlpha, precision: 0) else {
                return nil
            }

            return (rate, stake)
        }

        let totalStake = weighted.reduce(Decimal.zero) { $0 + $1.stake }

        guard totalStake > 0 else {
            return nil
        }

        return weighted.reduce(Decimal.zero) { $0 + $1.rate * $1.stake } / totalStake
    }
}
