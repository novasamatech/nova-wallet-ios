import Foundation
import BigInt

extension BigUInt {
    func saturatingSub(_ value: BigUInt) -> BigUInt {
        self > value ? self - value : 0
    }
}
