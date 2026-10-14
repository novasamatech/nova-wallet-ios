import Foundation
import BigInt

enum BittensorApiDecimalError: Error, Equatable {
    case invalid(String)
}

enum BittensorApiDecimal {
    static func decimal(_ value: String) throws -> Decimal {
        let shape = try Shape(value)

        guard
            shape.integerDigitCount <= Self.maxIntegerDigits,
            let result = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")),
            !result.isNaN else {
            throw BittensorApiDecimalError.invalid(value)
        }

        return result
    }

    static func atomic(_ value: String, scale: Int) throws -> BigUInt {
        let shape = try Shape(value)

        guard
            scale >= 0,
            shape.fractionDigitCount <= scale,
            !shape.isNegative || shape.magnitude == 0 else {
            throw BittensorApiDecimalError.invalid(value)
        }

        return shape.magnitude * BigUInt(10).power(scale - shape.fractionDigitCount)
    }

    static func fraction(_ value: String) throws -> BigRational {
        let shape = try Shape(value)

        guard !shape.isNegative || shape.magnitude == 0 else {
            throw BittensorApiDecimalError.invalid(value)
        }

        return BigRational(
            numerator: shape.magnitude,
            denominator: BigUInt(10).power(shape.fractionDigitCount)
        )
    }
}

private extension BittensorApiDecimal {
    static let maxLength = 1024
    static let maxIntegerDigits = 165

    struct Shape {
        let isNegative: Bool
        let integerDigitCount: Int
        let fractionDigitCount: Int
        let magnitude: BigUInt

        init(_ value: String) throws {
            let isNegative = value.hasPrefix("-")
            let parts = value.dropFirst(isNegative ? 1 : 0).split(
                separator: ".",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )
            let integer = parts[0]
            let fraction = parts.count > 1 ? parts[1] : ""
            let digits = integer + fraction

            guard
                (1 ... BittensorApiDecimal.maxLength).contains(value.utf8.count),
                integer.count == 1 || integer.first != "0",
                parts.count == 1 || !fraction.isEmpty,
                !integer.isEmpty,
                digits.allSatisfy({ $0.isASCII && $0.isNumber }),
                let magnitude = BigUInt(digits, radix: 10) else {
                throw BittensorApiDecimalError.invalid(value)
            }

            self.isNegative = isNegative
            integerDigitCount = integer.count
            fractionDigitCount = fraction.count
            self.magnitude = magnitude
        }
    }
}
