import Foundation

enum SubtensorAlphaApyFormatter {
    static func annualRate(
        for hotkey: AccountId,
        in yields: SubtensorAlphaYields?,
        includesUnreliable: Bool = false
    ) -> Decimal? {
        guard let yields, yields.stamp.freshness == .fresh, let yield = yields.yields[hotkey] else {
            return nil
        }

        return includesUnreliable ? yield.annualRateIgnoringReliability : yield.annualRate
    }
}
