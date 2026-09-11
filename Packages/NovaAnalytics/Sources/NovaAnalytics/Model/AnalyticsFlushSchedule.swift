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
            return !isHoldingOff(now: now)
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

    /// The gateway hint is a floor under the escalating window, never a replacement for it.
    mutating func recordFailure(_ error: Error, now: Date) {
        failureCount += 1

        let escalated = min(
            Constants.backoffBase * pow(2, Double(failureCount - 1)),
            Constants.backoffMax
        )

        let window = min(
            max(Self.retryHint(in: error) ?? 0, escalated),
            Constants.maxWindow
        )

        nextFlushAllowedAt = now.addingTimeInterval(window)
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
        static let maxWindow: TimeInterval = 86400
    }

    /// A window further out than the longest one `recordFailure` can arm means the clock moved back.
    func isHoldingOff(now: Date) -> Bool {
        now < nextFlushAllowedAt && nextFlushAllowedAt <= now.addingTimeInterval(Constants.maxWindow)
    }

    static func retryHint(in error: Error) -> TimeInterval? {
        guard
            let transportError = error as? AnalyticsTransportError,
            case let .retryLater(_, retryAfter) = transportError
        else {
            return nil
        }

        return retryAfter
    }
}
