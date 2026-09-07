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
    private var recordedAttestationKeyIds: [String] = []
    private var recordedAssertionHashes: [Data] = []

    var assertionClientDataHashes: [Data] {
        synchronised { recordedAssertionHashes }
    }

    var attestationKeyIds: [String] {
        synchronised { recordedAttestationKeyIds }
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
        _ keyId: String,
        clientDataHash _: Data,
        completionHandler: @escaping (Data?, Error?) -> Void
    ) {
        synchronised { recordedAttestationKeyIds.append(keyId) }

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

    var keyGenerationError: Error?
    var attestationError: Error?
    var assertionResult: Result<AppAttestAssertion, Error> = .success(Data("assertion".utf8))

    var onAttestation: (() -> Void)?

    private let mutex = NSLock()
    private var recordedGenerateKeyCalls = 0
    private var recordedGeneratedKeyIds: [AppAttestKeyId] = []
    private var recordedAttestationKeyIds: [AppAttestKeyId] = []
    private var recordedAssertionKeyIds: [AppAttestKeyId] = []
    private var recordedAssertionClientData: [() throws -> Data] = []

    var generateKeyCallCount: Int {
        synchronised { recordedGenerateKeyCalls }
    }

    var generatedKeyIds: [AppAttestKeyId] {
        synchronised { recordedGeneratedKeyIds }
    }

    var attestationKeyIds: [AppAttestKeyId] {
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
            recordedGenerateKeyCalls = 0
            recordedGeneratedKeyIds = []
            recordedAttestationKeyIds = []
            recordedAssertionKeyIds = []
            recordedAssertionClientData = []
        }
    }

    func createKeyGenerationOperation() -> BaseOperation<AppAttestKeyId> {
        let error = keyGenerationError

        let keyId: AppAttestKeyId = synchronised {
            recordedGenerateKeyCalls += 1

            let generated = "generated-key-\(UUID().uuidString)"
            recordedGeneratedKeyIds.append(generated)

            return generated
        }

        return ClosureOperation {
            if let error {
                throw AppAttestServiceError.keyIdGeneration(error)
            }

            return keyId
        }
    }

    func createAttestationWrapper(
        using keyId: AppAttestKeyId,
        clientData: @escaping (AppAttestKeyId) throws -> Data
    ) -> CompoundOperationWrapper<AppAttestAttestation> {
        synchronised { recordedAttestationKeyIds.append(keyId) }

        let hook = onAttestation
        let error = attestationError

        return CompoundOperationWrapper(targetOperation: ClosureOperation {
            _ = try clientData(keyId)

            hook?()

            if let error {
                throw error
            }

            return AppAttestAttestation(
                keyId: keyId,
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
    private var recordedRegisterCalls = 0

    var challengeCallCount: Int {
        synchronised { recordedChallengeCalls }
    }

    var registerCallCount: Int {
        synchronised { recordedRegisterCalls }
    }

    func reset() {
        synchronised {
            recordedChallengeCalls = 0
            recordedRegisterCalls = 0
        }
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

        return ClosureOperation { [weak self] in
            hook?()

            let request = try requestClosure()

            self?.recordRegisterCall()

            onRequest?(request)

            if let error {
                throw error
            }
        }
    }

    private func recordRegisterCall() {
        synchronised { recordedRegisterCalls += 1 }
    }

    private func synchronised<T>(_ body: () -> T) -> T {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return body()
    }
}
