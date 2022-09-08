import Foundation

extension Decimal {
    func rounded(_ rule: FloatingPointRoundingRule) -> Decimal {
        var lhs = self
        lhs.round(rule)
        return lhs
    }

    mutating func round(_ rule: FloatingPointRoundingRule) {
        let mode: RoundingMode

        switch rule {
        case .toNearestOrAwayFromZero:
            mode = .plain
        case .toNearestOrEven:
            mode = .bankers
        case .up:
            mode = .up
        case .down:
            mode = .down
        case .towardZero:
            mode = self < 0 ? .up : .down
        case .awayFromZero:
            mode = self < 0 ? .down : .up
        @unknown default:
            mode = .plain
        }

        var lhs = self
        NSDecimalRound(&self, &lhs, 0, mode)
    }
}
