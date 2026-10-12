import Foundation

enum NovaAuthTokenValidation {
    static func remaining(
        _ record: NovaAuthTokenRecord,
        context: NovaAuthContext,
        clientID: String?,
        now: NovaAuthTime
    ) throws -> TimeInterval {
        guard record.version == 1, record.context == context, record.flow == "bittensor-read",
              clientID == nil || record.clientID == clientID,
              record.issuanceStart.bootID == now.bootID, !now.bootID.isEmpty,
              now.continuousSeconds.isFinite, now.continuousSeconds >= 0,
              record.issuanceStart.continuousSeconds.isFinite,
              record.issuanceStart.continuousSeconds >= 0,
              record.issuanceStart.continuousSeconds <= now.continuousSeconds else {
            throw NovaAuthError.credentialUnavailable
        }
        try NovaAuthValidation.clientID(record.clientID)
        try NovaAuthValidation.token(record.accessToken)
        let lifetime = record.expiresAt.subtractingReportingOverflow(record.issuedAt)
        guard record.issuedAt >= 0, !lifetime.overflow, (60 ... 900).contains(lifetime.partialValue) else {
            throw NovaAuthError.credentialUnavailable
        }
        let duration = Double(lifetime.partialValue)
        let lower = Int((duration * 0.20).rounded())
        let upper = Int((duration * (0.20 + 1.0 / 15.0)).rounded())
        guard (lower ... upper).contains(record.earlyRefreshSeconds) else {
            throw NovaAuthError.credentialUnavailable
        }
        let deadline = record.issuanceStart.continuousSeconds + duration - 5
        guard deadline.isFinite, deadline > now.continuousSeconds else {
            throw NovaAuthError.credentialUnavailable
        }
        return deadline - now.continuousSeconds
    }
}
