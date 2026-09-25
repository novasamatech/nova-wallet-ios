import Foundation
import BigInt

enum BittensorApiDecimalError: Error, Equatable {
    case invalid(String)
}

enum BittensorApiDecimal {
    static func decimal(_ value: String) throws -> Decimal {
        let lexeme = try Lexeme(value)

        var significand = lexeme.magnitude
        var exponent = -lexeme.fractionDigitCount

        guard significand > 0 else {
            return 0
        }

        let droppedDigits = max(
            significand.description.count - Self.maxSignificantDigits,
            Self.minExponent - exponent,
            0
        )

        if droppedDigits > 0 {
            significand = roundedHalfUp(significand, droppingDigits: droppedDigits)
            exponent += droppedDigits
        }

        guard significand > 0 else {
            return 0
        }

        while significand % 10 == 0 {
            significand /= 10
            exponent += 1
        }

        let digits = significand.description

        guard digits.count + exponent <= Self.maxIntegerDigits else {
            throw BittensorApiDecimalError.invalid(value)
        }

        let plainValue = plainString(digits: digits, exponent: exponent, isNegative: lexeme.isNegative)

        guard
            let result = Decimal(string: plainValue, locale: Locale(identifier: "en_US_POSIX")),
            !result.isNaN else {
            throw BittensorApiDecimalError.invalid(value)
        }

        return result
    }

    static func atomic(_ value: String, scale: Int) throws -> BigUInt {
        let lexeme = try Lexeme(value)

        guard
            scale >= 0,
            lexeme.fractionDigitCount <= scale,
            !lexeme.isNegative || lexeme.magnitude == 0 else {
            throw BittensorApiDecimalError.invalid(value)
        }

        return lexeme.magnitude * BigUInt(10).power(scale - lexeme.fractionDigitCount)
    }

    static func fraction(_ value: String) throws -> BigRational {
        let lexeme = try Lexeme(value)

        guard !lexeme.isNegative || lexeme.magnitude == 0 else {
            throw BittensorApiDecimalError.invalid(value)
        }

        return BigRational(
            numerator: lexeme.magnitude,
            denominator: BigUInt(10).power(lexeme.fractionDigitCount)
        )
    }
}

private extension BittensorApiDecimal {
    static let maxLength = 1024
    static let maxSignificantDigits = 38
    static let minExponent = -128
    static let maxIntegerDigits = 165

    struct Lexeme {
        let isNegative: Bool
        let fractionDigitCount: Int
        let magnitude: BigUInt

        init(_ value: String) throws {
            let bytes = Array(value.utf8)

            guard (1 ... BittensorApiDecimal.maxLength).contains(bytes.count) else {
                throw BittensorApiDecimalError.invalid(value)
            }

            let isNegative = bytes[0] == UInt8(ascii: "-")
            let integerStart = isNegative ? 1 : 0
            let integerEnd = Self.digitsEnd(in: bytes, from: integerStart)
            let integerCount = integerEnd - integerStart

            guard integerCount > 0, integerCount == 1 || bytes[integerStart] != UInt8(ascii: "0") else {
                throw BittensorApiDecimalError.invalid(value)
            }

            var fractionStart = integerEnd
            var fractionEnd = integerEnd

            if integerEnd < bytes.count {
                guard bytes[integerEnd] == UInt8(ascii: ".") else {
                    throw BittensorApiDecimalError.invalid(value)
                }

                fractionStart = integerEnd + 1
                fractionEnd = Self.digitsEnd(in: bytes, from: fractionStart)

                guard fractionEnd > fractionStart, fractionEnd == bytes.count else {
                    throw BittensorApiDecimalError.invalid(value)
                }
            }

            let digitBytes = bytes[integerStart ..< integerEnd] + bytes[fractionStart ..< fractionEnd]

            guard
                let digits = String(bytes: digitBytes, encoding: .ascii),
                let magnitude = BigUInt(digits, radix: 10) else {
                throw BittensorApiDecimalError.invalid(value)
            }

            self.isNegative = isNegative
            fractionDigitCount = fractionEnd - fractionStart
            self.magnitude = magnitude
        }

        private static func digitsEnd(in bytes: [UInt8], from start: Int) -> Int {
            var index = start

            while index < bytes.count, (UInt8(ascii: "0") ... UInt8(ascii: "9")).contains(bytes[index]) {
                index += 1
            }

            return index
        }
    }

    static func roundedHalfUp(_ value: BigUInt, droppingDigits count: Int) -> BigUInt {
        let divisor = BigUInt(10).power(count)
        let (quotient, remainder) = value.quotientAndRemainder(dividingBy: divisor)

        return remainder * 2 >= divisor ? quotient + 1 : quotient
    }

    static func plainString(digits: String, exponent: Int, isNegative: Bool) -> String {
        let body: String

        if exponent >= 0 {
            body = digits + String(repeating: "0", count: exponent)
        } else if digits.count > -exponent {
            body = String(digits.dropLast(-exponent)) + "." + String(digits.suffix(-exponent))
        } else {
            body = "0." + String(repeating: "0", count: -exponent - digits.count) + digits
        }

        return isNegative ? "-" + body : body
    }
}
