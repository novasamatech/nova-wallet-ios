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

    func greaterThanOrEqual(
        _ other: Decimal,
        _ roundingMode: NSDecimalNumber.RoundingMode
    ) -> Bool {
        let (lhs, rhs) = toShortestScale(self, other, roundingMode)

        return lhs >= rhs
    }

    func lessThanOrEqual(
        _ other: Decimal,
        _ roundingMode: NSDecimalNumber.RoundingMode
    ) -> Bool {
        let (lhs, rhs) = toShortestScale(self, other, roundingMode)

        return lhs <= rhs
    }

    private func toShortestScale(
        _ lhs: Decimal,
        _ rhs: Decimal,
        _ roundingMode: NSDecimalNumber.RoundingMode
    ) -> (lhs: Decimal, rhs: Decimal) {
        let lhsScale = lhs.scale
        let rhsScale = rhs.scale

        let targetScale = lhsScale <= rhsScale
            ? lhsScale
            : rhsScale

        let handler = NSDecimalNumberHandler(
            roundingMode: roundingMode,
            scale: Int16(targetScale),
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )

        let lhsRounded: Decimal
        let rhsRounded: Decimal

        if lhsScale == targetScale {
            lhsRounded = NSDecimalNumber(decimal: rhs)
                .rounding(accordingToBehavior: handler)
                .decimalValue
            rhsRounded = lhs
        } else {
            lhsRounded = NSDecimalNumber(decimal: lhs)
                .rounding(accordingToBehavior: handler)
                .decimalValue
            rhsRounded = rhs
        }

        return (lhsRounded, rhsRounded)
    }

    var scale: Int {
        let valueString = NSDecimalNumber(decimal: self).stringValue

        if let dotIndex = valueString.firstIndex(of: ".") {
            return valueString.distance(
                from: dotIndex,
                to: valueString.endIndex
            ) - 1
        } else {
            return 0
        }
    }
}
