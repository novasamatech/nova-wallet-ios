import Foundation

enum SubtensorRootRateCalculator {
    static func stakeWeightedRate(
        of positions: [SubtensorStakingPosition],
        in yields: SubtensorAlphaYields?
    ) -> Decimal? {
        guard let yields, yields.stamp.freshness == .fresh else {
            return nil
        }

        var totalStake = Decimal.zero
        var weightedRate = Decimal.zero

        for position in positions {
            guard
                let rate = yields.yields[position.hotkey]?.annualRate,
                let stake = Decimal.fromSubstrateAmount(position.stakeAlpha, precision: 0) else {
                return nil
            }

            totalStake += stake
            weightedRate += rate * stake
        }

        guard totalStake > 0 else {
            return nil
        }

        return weightedRate / totalStake
    }
}
