import Foundation
import Operation_iOS

protocol BackendAttestationProviderProtocol: AnyObject {
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

protocol BackendAttestationRemoteFactoryProtocol {
    func createChallengeWrapper() -> CompoundOperationWrapper<String>

    func createRegisterOperation(
        _ requestClosure: @escaping () throws -> BackendAttestationRegisterRequest
    ) -> BaseOperation<Void>
}

protocol BackendAttestationIdentityProtocol {
    /// Increments on every consent-cycle boundary. The chain re-checks consent against
    /// this, never by calling `clientId()` again — that accessor mints.
    var consentEpoch: Int { get }

    /// `nil` once forgotten and not re-armed.
    func clientId() -> String?
    func forgetClientId()
    func allowCreation()
}

enum BackendAttestationError: Error {
    case rejected(statusCode: Int)
    case clientError(statusCode: Int)
    case serverError(statusCode: Int)
    case unsupported
}

/// `Equatable` so the mode ladder can be asserted directly.
enum BackendAttestationMode: Equatable {
    case appAttest
    case none
    case unavailable
}

/// `HttpHeaderKey` in Operation-iOS carries only `contentType` and `authorization`,
/// hence this enum.
enum AttestationHeaderKey: String {
    case clientId = "X-Client-Id"
    case challenge = "X-Challenge"
    case signature = "X-Signature"
}

/// `public_key` is deliberately absent — the public key travels inside the attestation's
/// certificate and `key_id` takes its place in the digest (spec §7.6).
struct BackendAttestationRegisterRequest: Encodable {
    let clientId: String
    let platform: String
    let appPackage: String
    let attestationType: String
    let keyId: String
    let challenge: String
    let integrityToken: String

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
