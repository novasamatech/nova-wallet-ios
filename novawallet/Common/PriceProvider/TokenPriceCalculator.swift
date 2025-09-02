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

        if time >= history.items[lastUsedIndex].startedAt {
            let startIndex = lastUsedIndex
            return startIndex ..< history.items.count
        } else {
            return 0 ..< (lastUsedIndex + 1)
        }
    }
}

extension TokenPriceCalculator: TokenPriceCalculatorProtocol {
    func calculatePrice(for time: UInt64) -> Decimal? {
        guard
            let priceStartTimestamp = history.items.first?.startedAt,
            time >= priceStartTimestamp else {
            return nil
        }

        let searchRange = findSearchRange(for: time)

        // this is the index of the element that is not less then time
        let result = history.items[searchRange].partitioningIndex { time <= $0.startedAt }
        let foundIndex = min(result, history.items.count - 1)

        if history.items[foundIndex].startedAt > time {
            let prevIndex = max(foundIndex - 1, 0)
            lastUsedIndex = prevIndex
            return history.items[prevIndex].value
        } else {
            lastUsedIndex = foundIndex
            return history.items[foundIndex].value
        }
    }
}
