import Foundation
import BigInt

struct BigRational {
    let numerator: BigUInt
    let denominator: BigUInt

    func mul(value: BigUInt) -> BigUInt {
        value * numerator / denominator
    }
}
