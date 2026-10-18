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
    func isBusy(keyID: String) -> Bool
    func createKeyWrapper() -> CompoundOperationWrapper<String>
    func createAttestationWrapper(
        keyID: String,
        clientDataHash: Data,
        beforeAttest: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<Data>
    func createAssertionWrapper(keyID: String, clientDataHash: Data) -> CompoundOperationWrapper<Data>
}

protocol NovaAuthIdentityStoreProtocol: AnyObject {
    func load() throws -> NovaAuthInstallationState?
    func save(_ state: NovaAuthInstallationState) throws
}

enum NovaAuthIdentityStoreError: Error, Equatable { case corrupt, resetPending }

protocol NovaAuthTokenStoreProtocol: AnyObject {
    func load() throws -> NovaAuthTokenRecord?
    func replace(_ record: NovaAuthTokenRecord) throws
    @discardableResult func remove(ifMatching record: NovaAuthTokenRecord) throws -> Bool
    func removeAll() throws
}

enum NovaAuthHTTPKind { case bootstrap, businessRead, businessPost }
protocol NovaAuthHTTPProtocol: AnyObject {
    func createResponseWrapper<T>(
        for request: URLRequest,
        kind: NovaAuthHTTPKind,
        beforeSend: @escaping () throws -> Void,
        decode: @escaping (NovaAuthResponse) throws -> T
    ) -> CompoundOperationWrapper<T>
}

enum NovaAuthAppAttestError: Error { case serverUnavailable, invalidKey, unsupported, failure, timedOut }
