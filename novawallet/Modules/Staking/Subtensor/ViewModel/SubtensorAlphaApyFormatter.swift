import Foundation

enum SubtensorAlphaApyFormatter {
    static func annualRate(from yield: SubtensorReportedYield?) -> Decimal? {
        yield?.annualRate
    }

    static func annualRate(for hotkey: AccountId, in yields: SubtensorAlphaYields?) -> Decimal? {
        guard let yields, yields.stamp.freshness == .fresh else {
            return nil
        }

        return annualRate(from: yields.yields[hotkey])
    }
}
