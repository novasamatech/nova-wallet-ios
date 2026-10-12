import Foundation

struct NovaAuthCooldown: Codable, Equatable {
    private(set) var deadline: NovaAuthTime?
    private(set) var failures = 0

    func check(now: NovaAuthTime) throws {
        if let deadline, deadline.bootID == now.bootID, deadline.continuousSeconds > now.continuousSeconds {
            throw NovaAuthError.cooldown(retryAfter: deadline.continuousSeconds - now.continuousSeconds)
        }
    }

    mutating func fail(
        now: NovaAuthTime,
        random: Double,
        retryAfter: TimeInterval? = nil,
        repeatingLastFailure: Bool = false
    ) {
        let sequence: [TimeInterval] = [1, 2, 4, 8, 16, 30]
        let jitter = random.isFinite ? min(1, max(0, random)) : 1
        let previousFailures = repeatingLastFailure ? max(0, failures - 1) : failures
        let fallback = sequence[min(previousFailures, sequence.count - 1)] + jitter
        let delay = retryAfter.flatMap { $0.isFinite && $0 >= 0 ? min(905, max(1, $0)) : nil } ?? fallback
        failures = min(previousFailures + 1, sequence.count)
        let next = now.continuousSeconds + delay
        if deadline?.bootID != now.bootID || (deadline?.continuousSeconds ?? 0) < next {
            deadline = NovaAuthTime(bootID: now.bootID, continuousSeconds: next)
        }
    }

    mutating func clear() {
        deadline = nil
        failures = 0
    }

    mutating func succeed(now: NovaAuthTime) {
        failures = 0
        if deadline?.bootID != now.bootID || (deadline?.continuousSeconds ?? 0) <= now.continuousSeconds {
            deadline = nil
        }
    }
}
