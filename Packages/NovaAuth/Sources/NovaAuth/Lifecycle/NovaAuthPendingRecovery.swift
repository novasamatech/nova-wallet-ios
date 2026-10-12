import Foundation

extension NovaAuth {
    func reservePendingProbe(flight: NovaAuthIssuanceFlight, now: NovaAuthTime) throws {
        guard case let .registrationPending(pending) = state?.identity?.registration else { return }
        try pending.cooldown.check(now: now)
        var cooldown = pending.cooldown
        cooldown.fail(now: now, random: dependencies.random.unitInterval())
        // Reserve the request and its backoff before sending, including when its response is lost.
        try setRegistration(.registrationPending(NovaAuthPendingRegistration(
            startedAt: pending.startedAt,
            unknownResponseCount: pending.unknownResponseCount,
            cooldown: cooldown
        )), flight: flight)
        flight.pendingProbeReserved = true
    }

    func confirmPendingBinding(flight: NovaAuthIssuanceFlight) throws {
        guard case let .registrationPending(pending) = state?.identity?.registration,
              pending.unknownResponseCount != 0 else { return }
        try setRegistration(.registrationPending(NovaAuthPendingRegistration(
            startedAt: pending.startedAt, unknownResponseCount: 0, cooldown: pending.cooldown
        )), flight: flight)
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
                unknownResponseCount: pending.unknownResponseCount,
                cooldown: cooldown
            )), flight: flight)
            issuanceCooldown = cooldown
        } else {
            issuanceCooldown.fail(now: now, random: random, retryAfter: retryAfter)
        }
        NovaAuthDiagnostics.cooldown(
            scope: .shared,
            delay: issuanceCooldown.deadline.map { .bounded(max(0, $0.continuousSeconds - now.continuousSeconds)) },
            logger: dependencies.logger
        )
    }
}
