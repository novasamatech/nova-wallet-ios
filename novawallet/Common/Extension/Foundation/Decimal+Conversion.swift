import Foundation
import BigInt

extension Decimal {
    static func fromSubstratePercent(value: UInt8) -> Decimal? {
        let decimalValue = NSDecimalNumber(value: value)
        return decimalValue.multiplying(byPowerOf10: -2).decimalValue
    }

    init?(_ bigUInt: BigUInt) {
        self.init(string: String(bigUInt))
    }
}
