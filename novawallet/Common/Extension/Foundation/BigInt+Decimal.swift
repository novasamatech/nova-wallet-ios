import Foundation
import BigInt

extension BigUInt {
    func decimal(precision: UInt16 = 0) -> Decimal {
        Decimal.fromSubstrateAmount(
            self,
            precision: Int16(precision)
        ) ?? 0
    }
}

extension Optional where Wrapped == BigUInt {
    func decimalOrZero(precision: UInt16) -> Decimal {
        guard let self = self, self != 0 else {
            return 0
        }
        return self.decimal(precision: precision)
    }
}
