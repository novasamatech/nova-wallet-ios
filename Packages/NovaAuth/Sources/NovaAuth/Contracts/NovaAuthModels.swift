import Foundation

struct NovaAuthChallenge: Codable, Equatable {
    let challenge: String
    let issuedAt: Int64
    let expiresAt: Int64
}

struct NovaAuthTokenResponse {
    let accessToken: String
    let issuedAt: Int64
    let expiresAt: Int64
}

struct NovaAuthRegistrationRequest {
    let origin: NovaAuthOrigin
    let clientID: String
    let challenge: String
    let appIdentity: NovaAuthAppIdentity
    let keyID: String
    let attestation: Data
    let contentType: String
}

struct NovaAuthTokenRequest {
    let origin: NovaAuthOrigin
    let clientID: String
    let challenge: String
    let assertion: Data
    let contentType: String
}

struct NovaAuthInstallationState: Codable, Equatable {
    let version: Int
    let context: NovaAuthContext
    var requiresUserAction: Bool
    let identity: NovaAuthInstallationIdentity?
    var recoveryCooldown: NovaAuthCooldown?
    var tokenRemovalOwed: Bool?
}

struct NovaAuthInstallationIdentity: Codable, Equatable {
    let clientID: String
    let keyID: String?
    let registration: NovaAuthRegistrationState
}

struct NovaAuthRegistrationAttempt: Codable, Equatable {
    let challenge: String
    let contentType: String
    let clientDataHash: Data
    let startedAt: NovaAuthTime
}

struct NovaAuthPendingRegistration: Codable, Equatable {
    let startedAt: NovaAuthTime
    let unknownResponseCount: Int
    let cooldown: NovaAuthCooldown

    init(startedAt: NovaAuthTime, unknownResponseCount: Int = 0, cooldown: NovaAuthCooldown = NovaAuthCooldown()) {
        self.startedAt = startedAt
        self.unknownResponseCount = unknownResponseCount
        self.cooldown = cooldown
    }

    private enum CodingKeys: String, CodingKey { case startedAt, unknownResponseCount, probeCount, cooldown }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try values.decode(NovaAuthTime.self, forKey: .startedAt)
        cooldown = try values.decode(NovaAuthCooldown.self, forKey: .cooldown)
        if values.contains(.unknownResponseCount) {
            unknownResponseCount = try values.decode(Int.self, forKey: .unknownResponseCount)
        } else {
            let reservedCount = try values.decode(Int.self, forKey: .probeCount)
            guard (0 ... 8).contains(reservedCount) else { throw NovaAuthIdentityStoreError.corrupt }
            // Earlier versions counted sent attempts, which are not evidence of an absent binding.
            unknownResponseCount = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(startedAt, forKey: .startedAt)
        try values.encode(unknownResponseCount, forKey: .unknownResponseCount)
        try values.encode(cooldown, forKey: .cooldown)
    }
}

enum NovaAuthRegistrationState: Codable, Equatable {
    case unregistered
    case appleInFlight(NovaAuthRegistrationAttempt)
    case appleDeferred(NovaAuthRegistrationAttempt)
    case registrationPending(NovaAuthPendingRegistration)
    case registered
    case retired(NovaAuthRetirementReason)
}

enum NovaAuthRetirementReason: String, Codable {
    case lostKey, interrupted, registrationRefused, registrationAbandoned
    case unrecoverableRegistration, policyRefused

    var requiresUserAction: Bool {
        switch self {
        case .lostKey, .interrupted: return false
        case .registrationRefused, .registrationAbandoned, .unrecoverableRegistration, .policyRefused: return true
        }
    }
}
struct NovaAuthTokenRecord: Codable, Equatable {
    let version: Int
    let context: NovaAuthContext
    let flow: String
    let clientID: String
    let accessToken: String
    let issuedAt: Int64
    let expiresAt: Int64
    let issuanceStart: NovaAuthTime
    let earlyRefreshSeconds: Int
}

enum NovaAuthPurpose {
    case registration, token
    var path: String {
        switch self {
        case .registration: return "/v1/attestation/profile-3/register"
        case .token: return "/v1/attestation/profile-3/tokens"
        }
    }

    var byte: UInt8 { self == .registration ? 1 : 3 }
}
