import Foundation

enum NovaAuthStoredValidation {
    static func time(_ time: NovaAuthTime) throws {
        guard (1 ... 128).contains(time.bootID.utf8.count), time.bootID.utf8.allSatisfy({ (33 ... 126).contains($0) }),
              time.continuousSeconds.isFinite,
              time.continuousSeconds >= 0 else { throw NovaAuthError.storageUnavailable }
    }

    static func identity(_ state: NovaAuthInstallationState) throws {
        guard state.version == 1 else { throw NovaAuthError.storageUnavailable }
        _ = try NovaAuthOrigin(state.context.origin.value)
        if let recovery = state.recovery {
            guard (0 ... 2).contains(recovery.backgroundRecreations) else { throw NovaAuthError.storageUnavailable }
            if let cooldown = recovery.recreationDelay {
                try validateCooldown(cooldown, maximumFailures: 4, allowsZeroCountDeadline: true)
            }
            if let cooldown = recovery.policyRetryDelay { try validateCooldown(cooldown, maximumFailures: 4) }
            if let cooldown = recovery.proofRetryDelay { try validateCooldown(cooldown, maximumFailures: 4) }
        }
        guard let identity = state.identity else { return }
        try NovaAuthValidation.clientID(identity.clientID)
        if let keyID = identity.keyID { try NovaAuthValidation.keyID(keyID) }
        try registration(identity)
    }

    private static func registration(_ identity: NovaAuthInstallationIdentity) throws {
        switch identity.registration {
        case .unregistered, .retired: break
        case let .appleInFlight(attempt), let .appleDeferred(attempt):
            guard identity.keyID != nil,
                  attempt.clientDataHash.count == 32 else { throw NovaAuthError.storageUnavailable }
            try NovaAuthValidation.challenge(attempt.challenge)
            try NovaAuthValidation.contentType(attempt.contentType)
            try time(attempt.startedAt)
        case let .registrationPending(pending):
            guard identity.keyID != nil else { throw NovaAuthError.storageUnavailable }
            try pendingRegistration(pending)
        case .registered:
            guard identity.keyID != nil else { throw NovaAuthError.storageUnavailable }
        }
    }

    static func pendingRegistration(_ pending: NovaAuthPendingRegistration) throws {
        try time(pending.startedAt)
        guard (0 ... 8).contains(pending.unknownResponseCount),
              (pending.startedAt.continuousSeconds + 120).isFinite
        else { throw NovaAuthError.storageUnavailable }
        try validateCooldown(pending.cooldown)
        if let deadline = pending.cooldown.deadline {
            if deadline.bootID == pending.startedAt.bootID {
                guard deadline.continuousSeconds >= pending.startedAt.continuousSeconds else {
                    throw NovaAuthError.storageUnavailable
                }
            }
        }
    }

    static func validateCooldown(
        _ cooldown: NovaAuthCooldown,
        maximumFailures: Int = 6,
        allowsZeroCountDeadline: Bool = false
    ) throws {
        guard (0 ... maximumFailures).contains(cooldown.failures) else { throw NovaAuthError.storageUnavailable }
        if let deadline = cooldown.deadline {
            try time(deadline)
            guard cooldown.failures > 0 || allowsZeroCountDeadline else { throw NovaAuthError.storageUnavailable }
        } else if cooldown.failures != 0 { throw NovaAuthError.storageUnavailable }
    }

    static func token(_ record: NovaAuthTokenRecord) throws {
        guard record.version == 1, record.flow == "bittensor-read" else { throw NovaAuthError.storageUnavailable }
        _ = try NovaAuthOrigin(record.context.origin.value)
        try NovaAuthValidation.clientID(record.clientID)
        try NovaAuthValidation.token(record.accessToken)
        try time(record.issuanceStart)
        let lifetime = Double(
            try NovaAuthValidation
                .lifetime(issuedAt: record.issuedAt, expiresAt: record.expiresAt, range: 60 ... 900)
        )
        let minimum = Int((lifetime * 0.20).rounded())
        let maximum = Int((lifetime * 0.20 + lifetime / 15).rounded())
        guard (minimum ... maximum).contains(record.earlyRefreshSeconds),
              (record.issuanceStart.continuousSeconds + lifetime - 5).isFinite
        else { throw NovaAuthError.storageUnavailable }
    }
}
