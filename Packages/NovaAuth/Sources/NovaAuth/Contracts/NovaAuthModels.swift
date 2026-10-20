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
    let identity: NovaAuthInstallationIdentity?
    var tokenRemovalOwed: Bool?
}

struct NovaAuthInstallationIdentity: Codable, Equatable {
    let clientID: String
    let keyID: String?
    let registration: NovaAuthRegistrationState
    var refusal: NovaAuthRefusal?
}

struct NovaAuthRegistrationAttempt: Codable, Equatable {
    let challenge: String
    let contentType: String
    let clientDataHash: Data
    let startedAt: NovaAuthTime
}

struct NovaAuthPendingRegistration: Codable, Equatable {
    let startedAt: NovaAuthTime
    let cooldown: NovaAuthCooldown

    init(startedAt: NovaAuthTime, cooldown: NovaAuthCooldown = NovaAuthCooldown()) {
        self.startedAt = startedAt
        self.cooldown = cooldown
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
}

struct NovaAuthTokenRecord: Codable, Equatable {
    let version: Int
    let context: NovaAuthContext
    let clientID: String
    let accessToken: String
    let issuedAt: Int64
    let expiresAt: Int64
    let issuanceStart: NovaAuthTime
    let earlyRefreshSeconds: Int
}

enum NovaAuthPurpose {
    case registration, token
    var route: NovaAuthBootstrapRoute {
        self == .registration ? .registration : .token
    }

    var path: String { route.path }

    var byte: UInt8 {
        self == .registration ? 1 : 3
    }
}
