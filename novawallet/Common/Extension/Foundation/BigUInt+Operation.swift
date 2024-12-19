import Foundation
import BigInt

extension BigUInt {
    func subtractOrZero(_ value: BigUInt) -> BigUInt {
        self > value ? self - value : 0
    }

    func divideByRoundingUp(_ value: BigUInt) -> BigUInt {
        let (quotient, reminder) = quotientAndRemainder(dividingBy: value)

        return reminder > 0 ? quotient + 1 : quotient
    }
}
