import Foundation

extension Decimal {
    enum Rounding {
        static func down(scale: Int32) -> NSDecimalNumberHandler {
            .init(
                roundingMode: .down,
                scale: Int16(truncatingIfNeeded: scale),
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            )
        }

        static func up(scale: Int32) -> NSDecimalNumberHandler {
            .init(
                roundingMode: .up,
                scale: Int16(truncatingIfNeeded: scale),
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            )
        }
    }
}
