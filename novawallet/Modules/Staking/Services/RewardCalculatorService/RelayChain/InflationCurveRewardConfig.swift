import Foundation

struct InflationCurveRewardConfig {
    let fallof: Decimal
    let minAnnualInflation: Decimal
    let maxAnnualInflation: Decimal
    let maxParachainsCount: Int
    let parachainsReserve: Decimal
    let idealStake: Decimal

    init(
        idealStake: Decimal = 0.75,
        fallof: Decimal = 0.05,
        minAnnualInflation: Decimal = 0.025,
        maxAnnualInflation: Decimal = 0.1,
        maxParachainsCount: Int = 60,
        parachainsReserve: Decimal = 0.3
    ) {
        self.idealStake = idealStake
        self.fallof = fallof
        self.minAnnualInflation = minAnnualInflation
        self.maxAnnualInflation = maxAnnualInflation
        self.maxParachainsCount = maxParachainsCount
        self.parachainsReserve = parachainsReserve
    }

    func idealStakePortion(for parachainsCount: Int) -> Decimal {
        let cappedParachains = min(parachainsCount, maxParachainsCount)
        let auctionPortion = Decimal(cappedParachains) / Decimal(maxParachainsCount) * parachainsReserve

        // Therefore the ideal amount at stake (as a percentage of total issuance) is 75% less the
        // amount that we expect to be taken up with auctions.
        return idealStake - auctionPortion
    }
}

extension InflationCurveRewardConfig {
    static func config(for chainId: ChainModel.Id) -> InflationCurveRewardConfig {
        switch chainId {
        case KnowChainId.polkadot:
            return InflationCurveRewardConfig(
                idealStake: 0.75,
                fallof: 0.05,
                minAnnualInflation: 0.025,
                maxAnnualInflation: 0.1,
                maxParachainsCount: 60,
                parachainsReserve: 0.2
            )
        default:
            return InflationCurveRewardConfig()
        }
    }
}
