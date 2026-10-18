import Foundation

enum SubtensorStakeRateCalculator {
    static func rootRate(
        of positions: [SubtensorStakingPosition],
        in yields: SubtensorAlphaYields?
    ) -> Decimal? {
        stakeWeightedRate(of: positions) { position in
            (annualRate(for: position, in: yields), position.stakeAlpha)
        }
    }

    static func subnetRate(
        of positions: [SubtensorStakingPosition],
        in yields: [UInt16: SubtensorAlphaYields],
        prices: SubtensorAlphaPrices?
    ) -> Decimal? {
        stakeWeightedRate(of: positions) { position in
            (
                annualRate(for: position, in: yields[position.netuid]),
                prices?.taoValue(of: position.stakeAlpha, netuid: position.netuid)
            )
        }
    }
}

private extension SubtensorStakeRateCalculator {
    static func annualRate(for position: SubtensorStakingPosition, in yields: SubtensorAlphaYields?) -> Decimal? {
        guard let yields, yields.stamp.freshness == .fresh else {
            return nil
        }

        return yields.yields[position.hotkey]?.annualRate
    }

    static func stakeWeightedRate(
        of positions: [SubtensorStakingPosition],
        rateAndStake: (SubtensorStakingPosition) -> (Decimal?, Balance?)
    ) -> Decimal? {
        var totalStake = Decimal.zero
        var weightedRate = Decimal.zero

        for position in positions {
            let (rate, stake) = rateAndStake(position)

            guard
                let rate,
                let stake = stake.flatMap({ Decimal.fromSubstrateAmount($0, precision: 0) }) else {
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
