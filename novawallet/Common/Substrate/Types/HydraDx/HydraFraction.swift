import Foundation
import BigInt

enum HydraFraction {
    static let one = BigUInt(1) << 127

    static func mul(_ lhs: BigUInt, _ rhs: BigUInt) -> BigUInt {
        (lhs * rhs) >> 127
    }

    static func saturatingPow(_ operand: BigUInt, exponent: UInt32) -> BigUInt {
        var result = one
        var powValue = operand

        let bits = UInt32.bitWidth - exponent.leadingZeroBitCount

        for index in 0 ..< bits {
            if (exponent >> UInt32(index)) & 1 == 1 {
                result = mul(result, powValue)
            }

            powValue = mul(powValue, powValue)
        }

        return result
    }

    static func powiNearOne(_ operand: BigUInt, exponent: UInt32) -> BigUInt? {
        let oneMinus = one - operand
        let power = BigUInt(exponent)
        let terms = Int(exponent)

        guard one / power > oneMinus else {
            return nil
        }

        var sumPositive = one
        var sumNegative = BigUInt(0)
        var term = one

        for index in 1 ..< 32 {
            let step = BigUInt(index)

            let scaled = oneMinus * (power - step + 1)
            let termFactor = scaled / step

            term = mul(term, termFactor)

            if index % 2 == 0 {
                sumPositive += term
            } else {
                sumNegative += term
            }

            if index >= terms || term == 0 {
                return sumPositive - sumNegative
            }
        }

        return nil
    }
}
