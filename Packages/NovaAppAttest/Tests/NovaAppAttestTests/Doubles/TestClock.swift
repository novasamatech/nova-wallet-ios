import Foundation

final class TestClock {
    private let mutex = NSLock()
    private var current: Date

    init(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        current = now
    }

    var now: Date {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return current
    }

    func advance(by interval: TimeInterval) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        current = current.addingTimeInterval(interval)
    }
}
