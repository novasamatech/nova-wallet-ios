import Foundation
import Operation_iOS

public protocol BackendAttestationProviderProtocol: AnyObject {
    /// `target` must describe the request the headers will travel on: profile 2 binds the proof to
    /// that exact method, origin, path and content type, so a proof cannot be moved to another one.
    func createSignedHeadersWrapper(
        target: AttestationRequestTarget,
        bodyClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?>

    func markUnattested()

    func forgetClient()

    func allowClient()
}

public protocol BackendAttestationRemoteFactoryProtocol {
    /// The frozen destination a registration proof commits to — the register POST itself, which is
    /// what the gateway rebuilds when it checks the attestation's nonce.
    func registerTarget() throws -> AttestationRequestTarget

    /// Challenges are bound to a client and a purpose: one issued to register cannot prove a
    /// request, and neither survives being used twice.
    func createChallengeWrapper(
        clientId: String,
        purpose: AttestationProfile2.Purpose
    ) -> CompoundOperationWrapper<String>

    func createRegisterOperation(
        _ requestClosure: @escaping () throws -> BackendAttestationRegisterRequest
    ) -> BaseOperation<Void>
}

public protocol BackendAttestationIdentityProtocol {
    var consentEpoch: Int { get }

    func clientId() -> String?

    /// Reads the stored identifier without minting one, so cleanup paths that must not create a
    /// client can still name the row that client owns.
    func existingClientId() -> String?

    /// Retires `clientId` so the next `clientId()` mints a new one, and only while it is still the
    /// stored one — a chain that failed under an identity the install has already moved on from must
    /// not retire its successor. Unlike `forgetClientId` this is recovery, not consent withdrawal:
    /// creation stays allowed and the consent epoch does not move.
    func resetClientId(ifCurrent clientId: String)

    func forgetClientId()
    func allowCreation()
}

/// The app identity a key is bound to.
///
/// `appId` is the full App ID: the App ID prefix Apple issued, a dot, then the bundle identifier.
/// The prefix is not assumed to be the team identifier, and it is not cosmetic — App Attest hashes
/// the full App ID into the authenticator data's `rpIdHash`, so a wrong prefix fails Apple's own
/// check inside the gateway and no server-side allowlist can rescue it.
public struct AppAttestAppIdentity: Equatable {
    public let appId: String
    /// `development` is Apple's sandbox. A TestFlight or App Store build always attests as
    /// `production` whatever the entitlement says.
    public let environment: String

    public init(appId: String, environment: String) {
        self.appId = appId
        self.environment = environment
    }
}

/// The gateway's error envelope. The status alone cannot say whether to retry, take a fresh
/// challenge, or retire the installation — only the code can, and under a 60-second single-use
/// challenge an expiry is routine rather than a verdict.
public enum BackendAttestationErrorCode: String, Decodable {
    case invalidRequest = "invalid_request"
    case unsupportedProfile = "unsupported_profile"
    case invalidTarget = "invalid_target"
    case unsupportedPlatform = "unsupported_platform"
    case unsupportedAttestationType = "unsupported_attestation_type"
    case unknownClient = "unknown_client"
    case invalidChallenge = "invalid_challenge"
    case invalidProof = "invalid_proof"
    case attestationFailed = "attestation_failed"
    case appNotAllowed = "app_not_allowed"
    case bindingNotAllowed = "binding_not_allowed"
    case clientAlreadyRegistered = "client_already_registered"
    case requestTooLarge = "request_too_large"
    case unsupportedMediaType = "unsupported_media_type"
    case attestationUnavailable = "attestation_unavailable"

    /// Apple issues one attestation per key, so a verdict that invalidates the binding costs a new
    /// key — and a key the gateway will never rebind costs a new installation identifier with it.
    public var requiresFreshInstallation: Bool {
        switch self {
        case .unknownClient, .attestationFailed, .clientAlreadyRegistered:
            true
        default:
            false
        }
    }

    /// Policy denials that trying again cannot fix.
    public var stopsRetrying: Bool {
        switch self {
        case .appNotAllowed, .bindingNotAllowed:
            true
        default:
            false
        }
    }
}

public enum BackendAttestationError: Error {
    /// The binding is gone or no longer matches our key, so the installation is rebuilt rather than
    /// retried as-is.
    case unauthorized(statusCode: Int)
    case rejected(statusCode: Int)
    case clientError(statusCode: Int)
    case serverError(statusCode: Int)
    case retryLater(until: Date)
    case unsupported
    case invalidResponse
}

public enum BackendAttestationMode: Equatable {
    case appAttest
    case unavailable
}

public enum AttestationHeaderKey: String {
    case profile = "X-Attestation-Profile"
    case clientId = "X-Client-Id"
    case challenge = "X-Challenge"
    /// iOS carries its proof here. The Android `X-Signature` header must never accompany it — the
    /// gateway requires exactly one platform proof and rejects a request carrying both.
    case appAttestAssertion = "X-App-Attest-Assertion"
}

public struct BackendAttestationRegisterRequest: Encodable {
    public let profile: Int
    public let clientId: String
    public let challenge: String
    public let platform: String
    public let appId: String
    public let attestationType: String
    /// Apple's key identifier, which is already the standard padded Base64 of its 32 raw bytes.
    public let keyReference: String
    public let appAttestEnvironment: String
    /// Standard padded Base64 of the App Attest attestation object.
    public let integrityToken: String

    enum CodingKeys: String, CodingKey {
        case profile
        case clientId = "client_id"
        case challenge
        case platform
        case appId = "app_id"
        case attestationType = "attestation_type"
        case keyReference = "key_reference"
        case appAttestEnvironment = "app_attest_environment"
        case integrityToken = "integrity_token"
    }
}
