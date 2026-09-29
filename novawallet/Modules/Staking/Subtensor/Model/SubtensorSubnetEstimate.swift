import BigInt
import Foundation

enum SubtensorSubnetEstimate {
    static func hold(amountTao: Balance, spot: Balance) -> Balance? {
        guard spot > 0 else {
            return nil
        }

        let novaFee = SubtensorNovaFeeConstants.rate.asShareOfGross.mul(value: amountTao)

        return (amountTao - novaFee) * SubtensorStakingPallet.alphaPriceScale / spot
    }

    static func monthly(hold: Balance, annualRate: BigRational) -> Balance {
        SubtensorEarningsEstimator.monthly(amount: hold, annualRate: annualRate)
    }

    static func annualRate(for hotkey: AccountId, in yields: SubtensorAlphaYields?) -> BigRational? {
        guard
            SubtensorAlphaApyFormatter.annualRate(for: hotkey, in: yields) != nil,
            let reportedRate = yields?.yields[hotkey]?.reportedRate,
            let reported = try? BittensorApiDecimal.fraction(reportedRate),
            let scale = SubtensorReportedYield.reportedRateScale.toSubstrateAmount(precision: 0),
            scale > 0 else {
            return nil
        }

        return BigRational(numerator: reported.numerator, denominator: reported.denominator * scale)
    }
}
