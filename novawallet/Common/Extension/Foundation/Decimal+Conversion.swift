import Foundation
import BigInt
import SubstrateSdk

extension Decimal {
    static func fromSubstratePercent(value: UInt8) -> Decimal? {
        let decimalValue = NSDecimalNumber(value: value)
        return decimalValue.multiplying(byPowerOf10: -2).decimalValue
    }

    static func fromFixedI64(value: Int64) -> Decimal {
        Decimal(value) / 1_000_000_000
    }

    static func fromSubstrateQuintill(value: BigUInt) -> Decimal? {
        fromSubstrateAmount(value, precision: 18)
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

    func ceil() -> Decimal {
        var originValue = self
        var rounded = Decimal()

        NSDecimalRound(&rounded, &originValue, 0, .up)

        return rounded
    }

    func divideToIntegralValue(by divisor: Decimal) -> Decimal {
        (self / divisor).floor()
    }

    func lessEpsilon() -> Decimal {
        if self == .zero {
            return self
        } else {
            let epsilon = 1 / pow(Decimal(10), -exponent)
            return self - epsilon
        }
    }

    static func rateFromSubstrate(
        amount1: BigUInt,
        amount2: BigUInt,
        precision1: Int16,
        precision2: Int16
    ) -> Decimal? {
        guard
            let decimal1 = fromSubstrateAmount(amount1, precision: precision1),
            let decimal2 = fromSubstrateAmount(amount2, precision: precision2),
            decimal2 > 0 else {
            return nil
        }

        return decimal2 / decimal1
    }
}
