import Foundation
import Operation_iOS
@testable import NovaAppAttest

/// Replaces `MockDeviceCheckAttesting`. Cuckoo is deliberately absent from package test
/// targets: these packages are staged for publication, and a consumer's CI must not have to
/// pull a code-generation plugin to run their tests.
final class DeviceCheckAttestingSpy: DeviceCheckAttesting {
    var isSupported: Bool = true

    var generateKeyResult: Result<String, Error> = .success("key-id")
    var attestKeyResult: Result<Data, Error> = .success(Data("attestation".utf8))
    var generateAssertionResult: Result<Data, Error> = .success(Data("assertion".utf8))

    private let mutex = NSLock()
    private var recordedGenerateKeyCalls = 0
    private var recordedAttestHashes: [Data] = []
    private var recordedAssertionHashes: [Data] = []

    /// Separate from the assertion hashes because the tests capture the argument of one
    /// specific call, the way the `ArgumentCaptor` they replace did.
    var attestClientDataHashes: [Data] {
        synchronised { recordedAttestHashes }
    }

    var assertionClientDataHashes: [Data] {
        synchronised { recordedAssertionHashes }
    }

    var generateKeyCallCount: Int {
        synchronised { recordedGenerateKeyCalls }
    }

    func generateKey(completionHandler: @escaping (String?, Error?) -> Void) {
        synchronised { recordedGenerateKeyCalls += 1 }

        switch generateKeyResult {
        case let .success(keyId): completionHandler(keyId, nil)
        case let .failure(error): completionHandler(nil, error)
        }
    }

    func attestKey(
        _: String,
        clientDataHash: Data,
        completionHandler: @escaping (Data?, Error?) -> Void
    ) {
        synchronised { recordedAttestHashes.append(clientDataHash) }

        switch attestKeyResult {
        case let .success(data): completionHandler(data, nil)
        case let .failure(error): completionHandler(nil, error)
        }
    }

    func generateAssertion(
        _: String,
        clientDataHash: Data,
        completionHandler: @escaping (Data?, Error?) -> Void
    ) {
        synchronised { recordedAssertionHashes.append(clientDataHash) }

        switch generateAssertionResult {
        case let .success(data): completionHandler(data, nil)
        case let .failure(error): completionHandler(nil, error)
        }
    }

    private func synchronised<T>(_ body: () -> T) -> T {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return body()
    }
}

/// Replaces `MockAppAttestServiceProtocol`.
///
/// Calls are recorded where the Cuckoo mock recorded them — when the wrapper is *composed* —
/// so `reset()` stands in for `clearInvocations` and the recorded arrays stand in for
/// `verify(times:)` and `ArgumentCaptor`.
final class AppAttestServiceSpy: AppAttestServiceProtocol {
    var isSupported: Bool = true

    /// Unwrapped inside the wrapper rather than at composition time — the provider's epoch
    /// guards run at execution time and the tests depend on a failure surfacing there.
    var assertionResult: Result<AppAttestAssertion, Error> = .success(Data("assertion".utf8))

    /// Fires inside the attestation operation, after the client data closure has run: the
    /// point at which the opt-out tests inject an opt-out mid-Apple-round-trip.
    var onAttestation: (() -> Void)?

    private let mutex = NSLock()
    private var recordedAttestationKeyIds: [AppAttestKeyId?] = []
    private var recordedAssertionKeyIds: [AppAttestKeyId] = []
    private var recordedAssertionClientData: [() throws -> Data] = []

    var attestationKeyIds: [AppAttestKeyId?] {
        synchronised { recordedAttestationKeyIds }
    }

    var assertionKeyIds: [AppAttestKeyId] {
        synchronised { recordedAssertionKeyIds }
    }

    var assertionClientDataClosures: [() throws -> Data] {
        synchronised { recordedAssertionClientData }
    }

    func reset() {
        synchronised {
            recordedAttestationKeyIds = []
            recordedAssertionKeyIds = []
            recordedAssertionClientData = []
        }
    }

    func createAttestationWrapper(
        using keyId: AppAttestKeyId?,
        clientData: @escaping (AppAttestKeyId) throws -> Data
    ) -> CompoundOperationWrapper<AppAttestAttestation> {
        synchronised { recordedAttestationKeyIds.append(keyId) }

        let hook = onAttestation
        let resolvedKeyId = keyId ?? UUID().uuidString

        return CompoundOperationWrapper(targetOperation: ClosureOperation {
            // Calling clientData is what exercises the digest construction and the epoch
            // gate the provider installs inside that closure.
            _ = try clientData(resolvedKeyId)

            hook?()

            return AppAttestAttestation(
                keyId: resolvedKeyId,
                attestation: Data("attestation-object".utf8)
            )
        })
    }

    func createAssertionWrapper(
        keyId: AppAttestKeyId,
        clientData: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<AppAttestAssertion> {
        synchronised {
            recordedAssertionKeyIds.append(keyId)
            recordedAssertionClientData.append(clientData)
        }

        let result = assertionResult

        return CompoundOperationWrapper(targetOperation: ClosureOperation {
            _ = try clientData()

            return try result.get()
        })
    }

    private func synchronised<T>(_ body: () -> T) -> T {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return body()
    }
}

/// Replaces `MockBackendAttestationRemoteFactoryProtocol`.
final class BackendAttestationRemoteFactorySpy: BackendAttestationRemoteFactoryProtocol {
    /// A closure rather than a stored `Result` because the gateway issues a fresh challenge
    /// per request (spec §7.5) and the Cuckoo stub this replaces did the same; a stored
    /// value would hand every request in a fixture the same challenge.
    var challenge: () throws -> String = { UUID().uuidString }
    var registerError: Error?

    /// Records requests that actually reached the transport. Counting
    /// `createRegisterOperation` calls would not do: the operation is *constructed* before
    /// an opt-out lands, and what must not happen is its request closure producing a value.
    var onRegisterRequest: ((BackendAttestationRegisterRequest) -> Void)?

    /// Runs at the top of the register operation, before its request closure — the hook the
    /// "opt out just before the register POST" tests fire.
    var onRegister: (() -> Void)?

    /// Runs before the challenge wrapper resolves — the hook the opt-out tests fire.
    var onChallenge: (() -> Void)?

    private let mutex = NSLock()
    private var recordedChallengeCalls = 0

    var challengeCallCount: Int {
        synchronised { recordedChallengeCalls }
    }

    func reset() {
        synchronised { recordedChallengeCalls = 0 }
    }

    func createChallengeWrapper() -> CompoundOperationWrapper<String> {
        synchronised { recordedChallengeCalls += 1 }

        let challenge = challenge
        let hook = onChallenge

        return CompoundOperationWrapper(targetOperation: ClosureOperation {
            hook?()

            return try challenge()
        })
    }

    func createRegisterOperation(
        _ requestClosure: @escaping () throws -> BackendAttestationRegisterRequest
    ) -> BaseOperation<Void> {
        let error = registerError
        let hook = onRegister
        let onRequest = onRegisterRequest

        return ClosureOperation {
            hook?()

            let request = try requestClosure()

            onRequest?(request)

            if let error {
                throw error
            }
        }
    }

    private func synchronised<T>(_ body: () -> T) -> T {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return body()
    }
}
