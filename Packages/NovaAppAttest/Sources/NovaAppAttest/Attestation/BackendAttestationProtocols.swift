import Foundation
import Operation_iOS

public protocol BackendAttestationProviderProtocol: AnyObject {
    /// `target` must match the request's method, origin, path and content type; the proof binds them.
    func createSignedHeadersWrapper(
        target: AttestationRequestTarget,
        bodyClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?>

    /// A rejected upload may retire only the installation whose identifier signed that request.
    func markUnattested(ifCurrentClientId clientId: String)

    func forgetClient()

    func allowClient()
}

public protocol BackendAttestationRemoteFactoryProtocol {
    /// Returns the registration POST target bound into the attestation's nonce.
    func registerTarget() throws -> AttestationRequestTarget

    /// Challenges are single-use and bound to a client and purpose.
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

    /// Reads the stored identifier without creating one, including during cleanup.
    func existingClientId() -> String?

    /// Retires only the matching stored identifier; stale failures cannot retire its successor.
    /// The next `clientId()` creates a new identifier without changing consent or its epoch.
    func resetClientId(ifCurrent clientId: String)

    func forgetClientId()
    func allowCreation()
}

/// `appId` must contain Apple's App ID prefix, a dot, and the bundle identifier for `rpIdHash`.
/// The App ID prefix is not necessarily the team identifier.
public struct AppAttestAppIdentity: Equatable {
    public let appId: String
    /// `development` selects Apple's sandbox; TestFlight and App Store builds use `production`.
    public let environment: String

    public init(appId: String, environment: String) {
        self.appId = appId
        self.environment = environment
    }
}

/// Error codes determine recovery; an HTTP status alone does not identify an invalid installation.
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

    // A client identifier cannot bind to another key, so both must be replaced together.
    public var requiresFreshInstallation: Bool {
        switch self {
        case .unknownClient, .attestationFailed, .clientAlreadyRegistered:
            true
        default:
            false
        }
    }

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
    /// The binding is missing or invalid; recovery requires a new installation identity.
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
    /// Must be the request's only platform proof header.
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
