import Foundation
import Operation_iOS

public protocol BackendAttestationProviderProtocol: AnyObject {
    /// `target` must describe the request the headers will travel on: the provider refuses to prove
    /// a request aimed anywhere but the gateway it registered with.
    func createSignedHeadersWrapper(
        target: AttestationRequestTarget,
        bodyClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?>

    func markUnattested()

    func forgetClient()

    func allowClient()
}

public protocol BackendAttestationRemoteFactoryProtocol {
    func createChallengeWrapper() -> CompoundOperationWrapper<String>

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

    /// Retires the stored identifier so the next `clientId()` mints a new one. Unlike
    /// `forgetClientId` this is recovery, not consent withdrawal: creation stays allowed and the
    /// consent epoch does not move, so a chain running under the current epoch survives it.
    func resetClientId()

    func forgetClientId()
    func allowCreation()
}

public enum BackendAttestationError: Error {
    /// The gateway stopped accepting this client. The binding is gone or no longer matches our key,
    /// so the identity is retired and rebuilt rather than retried as-is.
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
    case none
    case unavailable
}

public enum AttestationHeaderKey: String {
    case clientId = "X-Client-Id"
    case challenge = "X-Challenge"
    case signature = "X-Signature"
}

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
