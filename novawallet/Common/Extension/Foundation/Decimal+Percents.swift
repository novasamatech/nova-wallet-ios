import Foundation

extension Decimal {
    func fromFractionToPercents() -> Decimal {
        self * 100
    }

    func fromPercentsToFraction() -> Decimal {
        self / 100
    }
}
