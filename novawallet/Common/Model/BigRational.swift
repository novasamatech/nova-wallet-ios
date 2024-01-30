import Foundation
import BigInt

struct BigRational: Hashable {
    let numerator: BigUInt
    let denominator: BigUInt

    func mul(value: BigUInt) -> BigUInt {
        value * numerator / denominator
    }
}

extension BigUInt {
    func sub(rational: BigRational) -> BigRational? {
        let numerator = self * rational.denominator

        guard numerator >= rational.numerator else {
            return nil
        }

        return BigRational(
            numerator: numerator - rational.numerator,
            denominator: rational.denominator
        )
    }
}

extension BigRational {
    static func percent(of numerator: BigUInt) -> BigRational {
        .init(numerator: numerator, denominator: 100)
    }

    static func permill(of numerator: BigUInt) -> BigRational {
        .init(numerator: numerator, denominator: 1_000_000)
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

    var decimalOrZeroValue: Decimal {
        decimalValue ?? 0
    }
}
