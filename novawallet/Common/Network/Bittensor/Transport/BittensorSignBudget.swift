import Foundation

enum BittensorMonotonicClock {
    static func now() -> TimeInterval {
        TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / TimeInterval(NSEC_PER_SEC)
    }
}

struct BittensorSignBudget {
    enum Admission: Equatable {
        case granted
        case coolingDown
        case exhausted(nextAvailableAt: TimeInterval)
    }

    static let maxAttempts = 6
    static let window: TimeInterval = 60
    static let maxWait: TimeInterval = 45
    static let challengeCooldown: TimeInterval = 60

    private var attemptTimes: [TimeInterval] = []
    private var cooldownEnd: TimeInterval?

    mutating func admit(at time: TimeInterval) -> Admission {
        if let cooldownEnd, time < cooldownEnd {
            return .coolingDown
        }

        attemptTimes.removeAll { time - $0 >= Self.window }

        guard attemptTimes.count < Self.maxAttempts else {
            let oldestAttempt = attemptTimes.min() ?? time

            return .exhausted(nextAvailableAt: oldestAttempt + Self.window)
        }

        attemptTimes.append(time)

        return .granted
    }

    mutating func startCooldown(at time: TimeInterval) {
        cooldownEnd = time + Self.challengeCooldown
    }
}
