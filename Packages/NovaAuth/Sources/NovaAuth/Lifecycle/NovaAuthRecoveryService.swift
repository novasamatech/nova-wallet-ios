import Foundation

extension NovaAuth {
    func failPolicyRetryDelay() throws {
        guard var replacement = state else { throw NovaAuthError.generationChanged }
        var recovery = replacement.recovery ?? NovaAuthRecoveryState()
        var cooldown = recovery.policyRetryDelay ?? NovaAuthCooldown()
        cooldown.failLadder(now: try dependencies.clock.now(), random: dependencies.random.unitInterval(), caps: 600)
        recovery.policyRetryDelay = cooldown
        replacement.recovery = recovery
        try persist(replacement)
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
        cooldown.failLadder(now: try dependencies.clock.now(), random: dependencies.random.unitInterval(), caps: 86_400)
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
        NovaAuthDiagnostics.log(.identityRetired, logger: dependencies.logger)
    }
}
