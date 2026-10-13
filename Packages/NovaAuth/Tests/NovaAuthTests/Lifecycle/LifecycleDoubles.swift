import Foundation
import XCTest
import Operation_iOS
import NovaOperationSupport
@testable import NovaAuth

final class LifecycleClock: NovaAuthClockProtocol {
    private let lock = NSLock()
    private var time = NovaAuthTime(bootID: "boot-a", continuousSeconds: 100)
    var failure: Error?
    func now() throws -> NovaAuthTime { try lock.novaAuthLocked { if let failure { throw failure }; return time } }
    func advance(_ seconds: TimeInterval) { lock.novaAuthLocked { time = NovaAuthTime(bootID: time.bootID, continuousSeconds: time.continuousSeconds + seconds) } }
    func reboot() { lock.novaAuthLocked { time = NovaAuthTime(bootID: "boot-b", continuousSeconds: 1) } }
}

final class LifecycleRandom: NovaAuthRandomProtocol {
    private(set) var draws = 0
    private(set) var identifiers = 0
    var value = 0.5
    func makeClientID() -> String {
        identifiers += 1
        return String(format: "11111111-1111-4111-8111-%012d", identifiers)
    }

    func unitInterval() -> Double { draws += 1; return value }
}

final class LifecycleIdentityStore: NovaAuthIdentityStoreProtocol {
    private let lock = NSLock()
    var state: NovaAuthInstallationState?
    var failSave = false
    var failLoad = false
    var loadError: NovaAuthIdentityStoreError?
    var saves = 0
    func load() throws -> NovaAuthInstallationState? {
        try lock.novaAuthLocked {
            if failLoad { throw NovaAuthError.storageUnavailable }
            if let loadError { throw loadError }
            return state
        }
    }

    func save(_ state: NovaAuthInstallationState) throws {
        try lock.novaAuthLocked {
            if failSave { throw NovaAuthError.storageUnavailable }
            saves += 1
            self.state = state
            loadError = nil
        }
    }

    func markResetPending() throws {
        if failSave { throw NovaAuthError.storageUnavailable }
        state = nil
        loadError = .resetPending
    }
}

final class LifecycleTokenStore: NovaAuthTokenStoreProtocol {
    private let lock = NSLock()
    private var value: NovaAuthTokenRecord?
    var failLoad = false
    var failSave = false
    var failRemove = false
    var replacements = 0
    var onReplace: (() -> Void)?
    func load() throws -> NovaAuthTokenRecord? {
        try lock.novaAuthLocked { if failLoad { throw NovaAuthError.storageUnavailable }; return value }
    }

    func replace(_ record: NovaAuthTokenRecord) throws {
        try lock.novaAuthLocked {
            if failSave { throw NovaAuthError.storageUnavailable }
            value = record
            replacements += 1
        }
        onReplace?()
    }

    func remove(ifMatching record: NovaAuthTokenRecord) throws -> Bool {
        try lock.novaAuthLocked {
            if failRemove { throw NovaAuthError.storageUnavailable }
            guard value == record else { return false }
            value = nil
            return true
        }
    }

    func removeAll() throws {
        try lock.novaAuthLocked { if failRemove { throw NovaAuthError.storageUnavailable }; value = nil }
    }
}

final class LifecyclePending<Value> {
    private let lock = NSLock()
    private var completion: ((Result<Value, Error>) -> Void)?
    var onStart: (() -> Void)?
    var cancelled = false
    private(set) var operation: Operation?
    func start(_ completion: @escaping (Result<Value, Error>) -> Void) {
        lock.novaAuthLocked { self.completion = completion }
        onStart?()
    }

    func resolve(_ result: Result<Value, Error>) {
        let callback = lock.novaAuthLocked { () -> ((Result<Value, Error>) -> Void)? in
            let callback = completion
            completion = nil
            return callback
        }
        callback?(result)
    }

    func wrapper() -> CompoundOperationWrapper<Value> {
        let operation = AsyncClosureOperation<Value>(
            operationClosure: { [self] in start($0) },
            cancelationClosure: { [self] in cancelled = true }
        )
        self.operation = operation
        return CompoundOperationWrapper(targetOperation: operation)
    }
}

final class LifecycleApple: NovaAuthAppAttestProtocol {
    var isSupported = true
    var keys = 0
    var attestations: [(String, Data)] = []
    var assertions: [(String, Data)] = []
    var keyResult: Result<String, Error> = .success(Data(repeating: 1, count: 32).base64EncodedString())
    var attest: (() -> CompoundOperationWrapper<Data>)?
    var assert: (() -> CompoundOperationWrapper<Data>)?
    func isBusy(keyID _: String) -> Bool { false }

    func createKeyWrapper() -> CompoundOperationWrapper<String> {
        keys += 1
        return CompoundOperationWrapper(targetOperation: ClosureOperation { [self] in try keyResult.get() })
    }

    func createAttestationWrapper(
        keyID: String,
        clientDataHash: Data,
        beforeAttest: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<Data> {
        attestations.append((keyID, clientDataHash))
        let wrapper = attest?() ?? .createWithResult(Data([1, 2, 3]))
        let target = wrapper.targetOperation
        let configuration = target.configurationBlock
        target.configurationBlock = { [weak target] in
            configuration?()
            do { try beforeAttest() } catch { target?.result = .failure(error) }
        }
        return wrapper
    }

    func createAssertionWrapper(keyID: String, clientDataHash: Data) -> CompoundOperationWrapper<Data> {
        assertions.append((keyID, clientDataHash))
        return assert?() ?? .createWithResult(Data([4, 5, 6]))
    }
}

final class LifecycleBootstrap: NovaAuthBootstrapProtocol {
    static let challenge = NovaAuthChallenge(challenge: String(repeating: "A", count: 43), issuedAt: 1000, expiresAt: 1060)
    var registrationChallenges = 0
    var registrations: [NovaAuthRegistrationRequest] = []
    var tokenChallenges = 0
    var tokens: [NovaAuthTokenRequest] = []
    var tokenResult = NovaAuthTokenResponse(accessToken: "opaque-current-bearer", issuedAt: 1000, expiresAt: 1600)
    var registrationResult: Result<Void, Error> = .success(())
    var tokenChallengeResult: Result<NovaAuthChallenge, Error> = .success(challenge)
    var onRegistrationChallenge: ((@escaping (Result<NovaAuthChallenge, Error>) -> Void) -> Void)?
    var onRegister: ((@escaping (Result<Void, Error>) -> Void) -> Void)?
    var onTokenChallenge: ((@escaping (Result<NovaAuthChallenge, Error>) -> Void) -> Void)?
    var onToken: ((@escaping (Result<NovaAuthTokenResponse, Error>) -> Void) -> Void)?
    var onTokenCreated: (() -> Void)?
    var onTokenChallengeCreated: (() -> Void)?
    var tokenBeforeSendFailure: Error?
    private(set) var lastOperation: Operation?

    func createRegistrationChallengeWrapper(
        origin _: NovaAuthOrigin,
        clientID _: String,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthChallenge> {
        wrapper(beforeSend: beforeSend) { [self] completion in
            registrationChallenges += 1
            if let onRegistrationChallenge { onRegistrationChallenge(completion) }
            else { completion(.success(Self.challenge)) }
        }
    }

    func createRegistrationWrapper(
        _ request: NovaAuthRegistrationRequest,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<Void> {
        wrapper(beforeSend: beforeSend) { [self] completion in
            registrations.append(request)
            if let onRegister { onRegister(completion) } else { completion(registrationResult) }
        }
    }

    func createTokenChallengeWrapper(
        origin _: NovaAuthOrigin,
        clientID _: String,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthChallenge> {
        onTokenChallengeCreated?()
        return wrapper(beforeSend: beforeSend) { [self] completion in
            tokenChallenges += 1
            if let onTokenChallenge { onTokenChallenge(completion) } else { completion(tokenChallengeResult) }
        }
    }

    func createTokenWrapper(
        _ request: NovaAuthTokenRequest,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthTokenResponse> {
        onTokenCreated?()
        if let tokenBeforeSendFailure { return .createWithError(tokenBeforeSendFailure) }
        return wrapper(beforeSend: beforeSend) { [self] completion in
            tokens.append(request)
            if let onToken { onToken(completion) } else { completion(.success(tokenResult)) }
        }
    }

    private func wrapper<Value>(
        beforeSend: @escaping () throws -> Void,
        call: @escaping (@escaping (Result<Value, Error>) -> Void) -> Void
    ) -> CompoundOperationWrapper<Value> {
        let operation = AsyncClosureOperation<Value>(operationClosure: { completion in
            do { try beforeSend(); call(completion) } catch { completion(.failure(error)) }
        }, cancelationClosure: {})
        lastOperation = operation
        return CompoundOperationWrapper(targetOperation: operation)
    }
}

final class LifecycleHTTP: NovaAuthHTTPProtocol {
    private let lock = NSLock()
    private var sent: [URLRequest] = []
    var requests: [URLRequest] { lock.novaAuthLocked { sent } }
    var cleared = 0
    var handler: ((URLRequest, @escaping (Result<NovaAuthResponse, Error>) -> Void) -> Void)?
    func clearReadCache() { cleared += 1 }
    func createResponseWrapper(
        for request: URLRequest,
        kind _: NovaAuthHTTPKind,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthResponse> {
        let operation = AsyncClosureOperation<NovaAuthResponse>(operationClosure: { [self] completion in
            do {
                try beforeSend()
                lock.novaAuthLocked { sent.append(request) }
                if let handler { handler(request, completion) }
                else { completion(.success(try Self.response(request: request))) }
            } catch { completion(.failure(error)) }
        }, cancelationClosure: {})
        return CompoundOperationWrapper(targetOperation: operation)
    }

    static func response(
        request: URLRequest,
        status: Int = 200,
        headers: [String: String] = [:],
        body: Data = Data("{}".utf8)
    ) throws -> NovaAuthResponse {
        let url = try XCTUnwrap(request.url)
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers))
        return NovaAuthResponse(response: response, body: body)
    }
}
