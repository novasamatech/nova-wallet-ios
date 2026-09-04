import Foundation
import Operation_iOS

public protocol BackendAttestationProviderProtocol: AnyObject {
    /// nil ⇒ mode .none — the request goes out unsigned (dev builds only).
    func createSignedHeadersWrapper(
        bodyClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?>

    /// The gateway no longer knows this identity: drop the key row and re-attest with a NEW key.
    func markUnattested()

    /// Opt-out: drop the key row and the client id.
    func forgetClient()

    /// Re-consent: let the identity mint a new client id again after `forgetClient()`
    /// latched it shut.
    func allowClient()
}

public protocol BackendAttestationRemoteFactoryProtocol {
    func createChallengeWrapper() -> CompoundOperationWrapper<String>

    func createRegisterOperation(
        _ requestClosure: @escaping () throws -> BackendAttestationRegisterRequest
    ) -> BaseOperation<Void>
}

public protocol BackendAttestationIdentityProtocol {
    /// Increments on every consent-cycle boundary. The chain re-checks consent against
    /// this, never by calling `clientId()` again — that accessor mints.
    var consentEpoch: Int { get }

    /// `nil` once forgotten and not re-armed.
    func clientId() -> String?
    func forgetClientId()
    func allowCreation()
}

public enum BackendAttestationError: Error {
    case rejected(statusCode: Int)
    case clientError(statusCode: Int)
    case serverError(statusCode: Int)
    case unsupported

    /// A 2xx whose body the endpoint's decoder could not use — an empty challenge response,
    /// say. Lives here rather than in an attestation-internal error type so that a consumer
    /// of this package can catch everything `BackendAttestationRemoteFactory` throws by
    /// naming one public enum.
    case invalidResponse
}

/// `Equatable` so the mode ladder can be asserted directly.
public enum BackendAttestationMode: Equatable {
    case appAttest
    case none
    case unavailable
}

/// `HttpHeaderKey` in Operation-iOS carries only `contentType` and `authorization`,
/// hence this enum.
public enum AttestationHeaderKey: String {
    case clientId = "X-Client-Id"
    case challenge = "X-Challenge"
    case signature = "X-Signature"
}

/// `public_key` is deliberately absent — the public key travels inside the attestation's
/// certificate and `key_id` takes its place in the digest (spec §7.6).
public struct BackendAttestationRegisterRequest: Encodable {
    public let clientId: String
    public let platform: String
    public let appPackage: String
    public let attestationType: String
    public let keyId: String
    public let challenge: String
    public let integrityToken: String

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case platform
        case appPackage = "app_package"
        case attestationType = "attestation_type"
        case keyId = "key_id"
        case challenge
        case integrityToken = "integrity_token"
    }
}
