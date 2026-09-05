import Foundation
import Operation_iOS

public protocol BackendAttestationProviderProtocol: AnyObject {
    func createSignedHeadersWrapper(
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
    func forgetClientId()
    func allowCreation()
}

public enum BackendAttestationError: Error {
    case rejected(statusCode: Int)
    case clientError(statusCode: Int)
    case serverError(statusCode: Int)
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
