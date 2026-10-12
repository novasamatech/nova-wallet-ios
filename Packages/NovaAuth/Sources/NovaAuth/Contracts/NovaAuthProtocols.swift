import Foundation
import Operation_iOS

struct NovaAuthTime: Codable, Equatable {
    let bootID: String
    let continuousSeconds: TimeInterval
}

protocol NovaAuthClockProtocol { func now() throws -> NovaAuthTime }
protocol NovaAuthRandomProtocol {
    func makeClientID() -> String
    func unitInterval() -> Double
}

protocol NovaAuthAppAttestProtocol: AnyObject {
    var isSupported: Bool { get }
    func createKeyWrapper() -> CompoundOperationWrapper<String>
    func createAttestationWrapper(keyID: String, clientDataHash: Data) -> CompoundOperationWrapper<Data>
    func createAssertionWrapper(keyID: String, clientDataHash: Data) -> CompoundOperationWrapper<Data>
}

protocol NovaAuthIdentityStoreProtocol: AnyObject {
    func load() throws -> NovaAuthInstallationState?
    func save(_ state: NovaAuthInstallationState) throws
}

protocol NovaAuthTokenStoreProtocol: AnyObject {
    func load() throws -> NovaAuthTokenRecord?
    func replace(_ record: NovaAuthTokenRecord) throws
    @discardableResult func remove(ifMatching record: NovaAuthTokenRecord) throws -> Bool
    func removeAll() throws
}

protocol NovaAuthBootstrapProtocol: AnyObject {
    func createRegistrationChallengeWrapper(
        origin: NovaAuthOrigin,
        clientID: String,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthChallenge>
    func createRegistrationWrapper(_ request: NovaAuthRegistrationRequest, beforeSend: @escaping () throws -> Void)
        -> CompoundOperationWrapper<Void>
    func createTokenChallengeWrapper(origin: NovaAuthOrigin, clientID: String, beforeSend: @escaping () throws -> Void)
        -> CompoundOperationWrapper<NovaAuthChallenge>
    func createTokenWrapper(_ request: NovaAuthTokenRequest, beforeSend: @escaping () throws -> Void)
        -> CompoundOperationWrapper<NovaAuthTokenResponse>
}

enum NovaAuthHTTPKind { case bootstrap, businessRead, businessPost }
protocol NovaAuthHTTPProtocol: AnyObject {
    func createResponseWrapper(
        for request: URLRequest,
        kind: NovaAuthHTTPKind,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthResponse>
    func clearReadCache()
}

enum NovaAuthAppAttestError: Error { case serverUnavailable, invalidKey, unsupported, failure, timedOut }

protocol NovaAuthFileLockProtocol: AnyObject {
    func withLock<T>(_ body: () throws -> T) throws -> T
}
