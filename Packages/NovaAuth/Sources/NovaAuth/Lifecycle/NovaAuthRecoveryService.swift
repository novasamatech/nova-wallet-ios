import Foundation

extension NovaAuth {
    func failProofRetryDelay() throws {
        guard var replacement = state else { throw NovaAuthError.generationChanged }
        var recovery = replacement.recovery ?? NovaAuthRecoveryState()
        var cooldown = recovery.proofRetryDelay ?? NovaAuthCooldown()
        let now = try dependencies.clock.now()
        cooldown.failLadder(now: now, random: dependencies.random.unitInterval(), caps: 3600)
        recovery.proofRetryDelay = cooldown
        replacement.recovery = recovery
        try persist(replacement)
        logRecoveryCooldown(cooldown, scope: .proof, now: now)
    }

    func failPolicyRetryDelay() throws {
        guard var replacement = state else { throw NovaAuthError.generationChanged }
        var recovery = replacement.recovery ?? NovaAuthRecoveryState()
        var cooldown = recovery.policyRetryDelay ?? NovaAuthCooldown()
        let now = try dependencies.clock.now()
        cooldown.failLadder(now: now, random: dependencies.random.unitInterval(), caps: 600)
        recovery.policyRetryDelay = cooldown
        replacement.recovery = recovery
        try persist(replacement)
        logRecoveryCooldown(cooldown, scope: .policy, now: now)
    }

    func checkRecoveryDelays(now: NovaAuthTime) throws {
        guard let recovery = state?.recovery else { return }
        if case .retired = state?.identity?.registration {
            try recovery.recreationDelay?.check(now: now)
        }
        try recovery.policyRetryDelay?.check(now: now)
        try recovery.proofRetryDelay?.check(now: now)
    }

    func checkRecreationPermission(reason: NovaAuthRetirementReason, intent: NovaAuthRequestIntent) throws {
        guard intent != .userInitiated else { return }
        guard !reason.requiresUserAction, (state?.recovery?.backgroundRecreations ?? 0) < 2 else {
            throw NovaAuthError.userActionRequired
        }
    }

    func reserveReplacement(flight: NovaAuthIssuanceFlight) throws {
        guard self.flight === flight else { throw NovaAuthError.cancelled }
        try validate(context: flight.context)
        guard var replacement = state, case let .retired(reason) = replacement.identity?.registration else {
            throw NovaAuthError.keyUnavailable
        }
        try checkRecreationPermission(reason: reason, intent: flight.intent)
        guard flight.intent != .userInitiated else { return }
        var recovery = replacement.recovery ?? NovaAuthRecoveryState()
        recovery.backgroundRecreations += 1
        replacement.recovery = recovery
        // A crash or cancellation can consume a reservation without returning a key.
        try persist(replacement)
    }

    func retire(_ reason: NovaAuthRetirementReason, flight: NovaAuthIssuanceFlight) throws {
        try validate(context: flight.context)
        guard let state, let identity = state.identity else { throw NovaAuthError.keyUnavailable }
        var recovery = state.recovery ?? NovaAuthRecoveryState()
        var cooldown = recovery.recreationDelay ?? NovaAuthCooldown()
        let now = try dependencies.clock.now()
        cooldown.failLadder(now: now, random: dependencies.random.unitInterval(), caps: 86400)
        recovery.recreationDelay = cooldown
        try persist(NovaAuthInstallationState(
            version: state.version,
            context: state.context,
            requiresUserAction: state.requiresUserAction,
            identity: NovaAuthInstallationIdentity(
                clientID: identity.clientID, keyID: identity.keyID, registration: .retired(reason)
            ),
            recovery: recovery,
            tokenRemovalOwed: state.tokenRemovalOwed
        ))
        NovaAuthDiagnostics.retired(reason, logger: dependencies.logger)
        logRecoveryCooldown(cooldown, scope: .recreation, now: now)
    }
}

private extension NovaAuth {
    func logRecoveryCooldown(_ cooldown: NovaAuthCooldown, scope: NovaAuthDiagnostics.CooldownScope, now: NovaAuthTime) {
        NovaAuthDiagnostics.cooldown(
            scope: scope,
            delay: cooldown.deadline.map { .localRecovery(max(0, $0.continuousSeconds - now.continuousSeconds)) },
            logger: dependencies.logger
        )
    }
}
