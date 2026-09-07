import Foundation

struct AnalyticsFlushSchedule {
    private(set) var lastFlushAt: Date = .distantPast
    private(set) var failureCount: Int = 0
    private(set) var nextFlushAllowedAt: Date = .distantPast

    func reason(forQueuedCount count: Int, now: Date) -> AnalyticsFlushReason? {
        let sinceLastFlush = now.timeIntervalSince(lastFlushAt)

        if count >= Constants.threshold, sinceLastFlush >= Constants.thresholdMinInterval {
            return .threshold
        }

        return sinceLastFlush >= Constants.interval ? .interval : nil
    }

    /// A launch flush carries the events of the previous run and a manual one is a developer action.
    func allows(reason: AnalyticsFlushReason, now: Date) -> Bool {
        switch reason {
        case .threshold, .interval, .background:
            return now >= nextFlushAllowedAt
        case .launch, .manual:
            return true
        }
    }

    mutating func recordStart(at now: Date) {
        lastFlushAt = now
    }

    mutating func recordSuccess() {
        failureCount = 0
        nextFlushAllowedAt = .distantPast
    }

    mutating func recordFailure(_ error: Error, now: Date) {
        if
            let transportError = error as? AnalyticsTransportError,
            case let .retryLater(_, retryAfter?) = transportError {
            nextFlushAllowedAt = now.addingTimeInterval(retryAfter)

            return
        }

        failureCount += 1

        nextFlushAllowedAt = now.addingTimeInterval(
            min(
                Constants.backoffBase * pow(2, Double(failureCount - 1)),
                Constants.backoffMax
            )
        )
    }

    mutating func forget() {
        lastFlushAt = .distantPast

        recordSuccess()
    }
}

// MARK: - Private

private extension AnalyticsFlushSchedule {
    enum Constants {
        static let threshold = 50
        static let interval: TimeInterval = 300
        static let thresholdMinInterval: TimeInterval = 15
        static let backoffBase: TimeInterval = 60
        static let backoffMax: TimeInterval = 3600
    }
}
