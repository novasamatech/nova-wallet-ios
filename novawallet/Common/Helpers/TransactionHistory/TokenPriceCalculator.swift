import Foundation
import Algorithms

protocol TokenPriceCalculatorProtocol {
    func calculatePrice(for time: UInt64) -> Decimal?
}

final class TokenPriceCalculator {
    let history: PriceHistory

    // Found index is saved each time search is performed to optimize next search for sorted data
    @Atomic(defaultValue: nil) var lastUsedIndex: Int?

    init(history: PriceHistory) {
        self.history = history
    }

    func findSearchRange(for time: UInt64) -> Range<Int> {
        guard let lastUsedIndex = lastUsedIndex else {
            return 0 ..< history.items.count
        }

        if history.items[lastUsedIndex].startedAt <= time {
            let startIndex = lastUsedIndex
            return startIndex ..< history.items.count
        } else {
            return 0 ..< (lastUsedIndex + 1)
        }
    }
}

extension TokenPriceCalculator: TokenPriceCalculatorProtocol {
    func calculatePrice(for time: UInt64) -> Decimal? {
        guard !history.items.isEmpty else {
            return nil
        }

        let searchRange = findSearchRange(for: time)

        let partialIndex = history.items[searchRange].partitioningIndex { $0.startedAt >= time }

        let fullIndex = min(searchRange.startIndex + partialIndex, history.items.count - 1)
        lastUsedIndex = fullIndex

        return history.items[fullIndex].value
    }
}
