import BigInt
import Foundation

enum SubtensorEarningsEstimator {
    static let monthsPerYear = BigUInt(12)

    static func monthly(amount: Balance, annualRate: BigRational) -> Balance {
        guard annualRate.denominator > 0 else {
            return 0
        }

        return amount * annualRate.numerator / (annualRate.denominator * monthsPerYear)
    }
}
