import Foundation
import BigInt

extension Decimal {
    static func fromSubstratePercent(value: UInt8) -> Decimal? {
        let decimalValue = NSDecimalNumber(value: value)
        return decimalValue.multiplying(byPowerOf10: -2).decimalValue
    }

    static func fromFixedI64(value: Int64) -> Decimal {
        Decimal(value) / 1_000_000_000
    }

    init?(_ bigUInt: BigUInt) {
        self.init(string: String(bigUInt))
    }

    func floor() -> Decimal {
        var originValue = self
        var rounded = Decimal()

        NSDecimalRound(&rounded, &originValue, 0, .down)

        return rounded
    }
}
