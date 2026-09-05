import Foundation
import Operation_iOS
@testable import NovaAppAttest

final class DeviceCheckAttestingSpy: DeviceCheckAttesting {
    var isSupported: Bool = true

    var generateKeyResult: Result<String, Error> = .success("key-id")
    var attestKeyResult: Result<Data, Error> = .success(Data("attestation".utf8))
    var generateAssertionResult: Result<Data, Error> = .success(Data("assertion".utf8))

    private let mutex = NSLock()
    private var recordedGenerateKeyCalls = 0
    private var recordedAssertionHashes: [Data] = []

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
        clientDataHash _: Data,
        completionHandler: @escaping (Data?, Error?) -> Void
    ) {
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

final class AppAttestServiceSpy: AppAttestServiceProtocol {
    var isSupported: Bool = true

    var assertionResult: Result<AppAttestAssertion, Error> = .success(Data("assertion".utf8))

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

final class BackendAttestationRemoteFactorySpy: BackendAttestationRemoteFactoryProtocol {
    var challenge: () throws -> String = { UUID().uuidString }
    var registerError: Error?

    var onRegisterRequest: ((BackendAttestationRegisterRequest) -> Void)?

    var onRegister: (() -> Void)?

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
