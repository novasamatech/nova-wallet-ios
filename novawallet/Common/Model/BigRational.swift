import Foundation
import BigInt

struct BigRational {
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
