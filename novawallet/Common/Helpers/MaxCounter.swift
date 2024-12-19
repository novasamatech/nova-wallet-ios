import Foundation

struct MaxCounter {
    let maxCount: Int

    private var counter: Int = 0

    init(maxCount: Int) {
        self.maxCount = maxCount
    }

    mutating func incrementCounterIfPossible() -> Bool {
        if counter < maxCount {
            counter += 1

            return true
        } else {
            return false
        }
    }

    mutating func resetCounter() {
        counter = 0
    }
}

extension MaxCounter {
    static func feeCorrection() -> MaxCounter {
        MaxCounter(maxCount: 2)
    }
}
