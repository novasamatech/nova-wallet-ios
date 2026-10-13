import Foundation

enum NovaAuthTokenValidation {
    // Both persisted reads and live admission use the same credential structure and deadline.
    static func deadline(_ record: NovaAuthTokenRecord) throws -> TimeInterval {
        guard record.version == 2 else { throw NovaAuthError.credentialUnavailable }
        _ = try NovaAuthOrigin(record.context.origin.value)
        try NovaAuthValidation.clientID(record.clientID)
        try NovaAuthValidation.token(record.accessToken)
        try NovaAuthStoredValidation.time(record.issuanceStart)
        let duration = Double(try NovaAuthValidation.lifetime(
            issuedAt: record.issuedAt, expiresAt: record.expiresAt, range: 60 ... 900
        ))
        let lower = Int((duration * 0.20).rounded())
        let upper = Int((duration * 0.20 + duration / 15).rounded())
        let deadline = record.issuanceStart.continuousSeconds + duration - 5
        guard (lower ... upper).contains(record.earlyRefreshSeconds), deadline.isFinite else {
            throw NovaAuthError.credentialUnavailable
        }
        return deadline
    }

    static func remaining(
        _ record: NovaAuthTokenRecord,
        context: NovaAuthContext,
        clientID: String?,
        now: NovaAuthTime
    ) throws -> TimeInterval {
        let deadline = try deadline(record)
        guard record.context == context, clientID == nil || record.clientID == clientID,
              record.issuanceStart.bootID == now.bootID,
              now.continuousSeconds.isFinite,
              record.issuanceStart.continuousSeconds <= now.continuousSeconds,
              deadline > now.continuousSeconds else { throw NovaAuthError.credentialUnavailable }
        return deadline - now.continuousSeconds
    }
}
