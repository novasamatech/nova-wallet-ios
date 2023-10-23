import Foundation
import BigInt

struct BigRational: Hashable {
    let numerator: BigUInt
    let denominator: BigUInt

    func mul(value: BigUInt) -> BigUInt {
        value * numerator / denominator
    }
}

extension BigRational {
    func toPercents() -> BigRational {
        let (quotient, reminder) = denominator.quotientAndRemainder(dividingBy: 100)

        if quotient > 0, reminder == 0 {
            return .init(numerator: numerator, denominator: quotient)
        } else {
            return .init(numerator: numerator * 100, denominator: denominator)
        }
    }

    func fromPercents() -> BigRational {
        let newDenominator = denominator * 100

        return .init(numerator: numerator, denominator: newDenominator)
    }

    static func percent(of numerator: BigUInt) -> BigRational {
        .init(numerator: numerator, denominator: 100)
    }
}

extension BigRational {
    static func fraction(from number: Decimal) -> BigRational? {
        let decimalNumber = NSDecimalNumber(decimal: number)
        guard decimalNumber.doubleValue.remainder(dividingBy: 1) != 0 else {
            return number.toSubstrateAmount(precision: 0).map {
                BigRational(numerator: $0, denominator: 1)
            }
        }
        let scale = -number.exponent
        if let numerator = number.toSubstrateAmount(precision: Int16(scale)),
           let denominator = Decimal(1).toSubstrateAmount(precision: Int16(scale)) {
            return .init(numerator: numerator, denominator: denominator)
        }

        return nil
    }
}

extension BigRational {
    var decimalValue: Decimal? {
        guard denominator != 0 else {
            return nil
        }
        let numerator = numerator.decimal(precision: 0)
        let denominator = denominator.decimal(precision: 0)
        return numerator / denominator
    }
}
