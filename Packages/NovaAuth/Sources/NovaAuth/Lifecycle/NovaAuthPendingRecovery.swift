import Foundation

extension NovaAuth {
    func reservePendingProbe(flight: NovaAuthIssuanceFlight, now: NovaAuthTime) throws {
        guard case let .registrationPending(pending) = state?.identity?.registration else { return }
        try pending.cooldown.check(now: now)
        var cooldown = pending.cooldown
        cooldown.fail(now: now, random: dependencies.random.unitInterval())
        try setRegistration(.registrationPending(NovaAuthPendingRegistration(
            startedAt: pending.startedAt,
            cooldown: cooldown
        )), flight: flight)
        flight.pendingProbeReserved = true
    }

    func failIssuanceCooldown(flight: NovaAuthIssuanceFlight, retryAfter: TimeInterval?) throws {
        let now = try dependencies.clock.now()
        let random = dependencies.random.unitInterval()
        if case let .registrationPending(pending) = state?.identity?.registration {
            var cooldown = pending.cooldown
            cooldown.fail(
                now: now,
                random: random,
                retryAfter: retryAfter,
                repeatingLastFailure: flight.pendingProbeReserved
            )
            try setRegistration(.registrationPending(NovaAuthPendingRegistration(
                startedAt: pending.startedAt,
                cooldown: cooldown
            )), flight: flight)
            issuanceCooldown = cooldown
        } else {
            issuanceCooldown.fail(now: now, random: random, retryAfter: retryAfter)
        }
    }
}
