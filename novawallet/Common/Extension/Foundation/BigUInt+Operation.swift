import Foundation
import BigInt

extension BigUInt {
    func subtractOrZero(_ value: BigUInt) -> BigUInt {
        self > value ? self - value : 0
    }
}
