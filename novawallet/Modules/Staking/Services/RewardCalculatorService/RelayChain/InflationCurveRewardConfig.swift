import Foundation

struct InflationCurveRewardConfig {
    let fallof: Decimal = 0.05
    let minAnnualInflation: Decimal = 0.025
    let maxAnnualInflation: Decimal = 0.1

    func idealStakePortion(for parachainsCount: Int) -> Decimal {
        // 30% reserved for up to 60 slots
        let auctionPortion = Decimal(min(parachainsCount, 60)) / 200

        // Therefore the ideal amount at stake (as a percentage of total issuance) is 75% less the
        // amount that we expect to be taken up with auctions.
        return 0.75 - auctionPortion
    }
}
