import Foundation

enum SubtensorAlphaApyFormatter {
    static func annualRate(for hotkey: AccountId, in yields: SubtensorAlphaYields?) -> Decimal? {
        guard let yields, yields.stamp.freshness == .fresh else {
            return nil
        }

        return yields.yields[hotkey]?.annualRate
    }
}
