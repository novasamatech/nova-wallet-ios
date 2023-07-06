import Foundation
import BigInt

extension BigUInt {
    func decimal(precision: UInt16) -> Decimal {
        Decimal.fromSubstrateAmount(
            self,
            precision: Int16(precision)
        ) ?? 0
    }
}
