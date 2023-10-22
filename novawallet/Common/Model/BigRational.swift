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
    static func percent(of numerator: BigUInt) -> BigRational {
        .init(numerator: numerator, denominator: 100)
    }
}

extension BigRational {
    static func fraction(from number: Decimal) -> BigRational {
        let decimalNumber = NSDecimalNumber(decimal: number)
        guard decimalNumber.doubleValue.remainder(dividingBy: 1) != 0 else {
            return .init(numerator: BigUInt(decimalNumber.int64Value), denominator: 1)
        }
        let scale = -number.exponent
        let numerator = decimalNumber.multiplying(byPowerOf10: Int16(scale)).intValue
        let denominator = Int(truncating: pow(10, scale) as NSNumber)
        return .init(numerator: BigUInt(numerator), denominator: BigUInt(denominator))
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
