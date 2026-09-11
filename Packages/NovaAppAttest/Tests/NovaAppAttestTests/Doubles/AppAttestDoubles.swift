import Foundation
import Operation_iOS
import SDKLogger
@testable import NovaAppAttest

final class DeviceCheckAttestingSpy: DeviceCheckAttesting {
    let isSupported = true
    var attestKeyResult: Result<Data, Error> = .success(Data("attestation".utf8))
    private(set) var assertionClientDataHashes: [Data] = []

    func generateKey(completionHandler: @escaping (String?, Error?) -> Void) {
        completionHandler("generated-key-id", nil)
    }

    func attestKey(_: String, clientDataHash _: Data, completionHandler: @escaping (Data?, Error?) -> Void) {
        switch attestKeyResult {
        case let .success(data): completionHandler(data, nil)
        case let .failure(error): completionHandler(nil, error)
        }
    }

    func generateAssertion(_: String, clientDataHash: Data, completionHandler: @escaping (Data?, Error?) -> Void) {
        assertionClientDataHashes.append(clientDataHash)
        completionHandler(Data("assertion".utf8), nil)
    }
}

final class AppAttestServiceSpy: AppAttestServiceProtocol {
    let isSupported = true
    var attestationError: Error?

    private(set) var generateKeyCallCount = 0
    private(set) var generatedKeyIds: [AppAttestKeyId] = []
    private(set) var attestationKeyIds: [AppAttestKeyId] = []
    private(set) var assertionKeyIds: [AppAttestKeyId] = []

    func reset() {
        generateKeyCallCount = 0
        generatedKeyIds = []
        attestationKeyIds = []
        assertionKeyIds = []
    }

    func createKeyGenerationOperation() -> BaseOperation<AppAttestKeyId> {
        generateKeyCallCount += 1
        let keyId = "generated-key-\(UUID().uuidString)"
        generatedKeyIds.append(keyId)
        return ClosureOperation { keyId }
    }

    func createAttestationWrapper(using keyId: AppAttestKeyId, clientData: @escaping (AppAttestKeyId) throws -> Data) -> CompoundOperationWrapper<AppAttestAttestation> {
        attestationKeyIds.append(keyId)
        let error = attestationError

        return CompoundOperationWrapper(targetOperation: ClosureOperation {
            _ = try clientData(keyId)
            if let error {
                throw error
            }

            return AppAttestAttestation(keyId: keyId, attestation: Data("attestation-object".utf8))
        })
    }

    func createAssertionWrapper(keyId: AppAttestKeyId, clientData: @escaping () throws -> Data) -> CompoundOperationWrapper<AppAttestAssertion> {
        assertionKeyIds.append(keyId)

        return CompoundOperationWrapper(targetOperation: ClosureOperation {
            _ = try clientData()
            return Data("assertion".utf8)
        })
    }
}

final class BackendAttestationRemoteFactorySpy: BackendAttestationRemoteFactoryProtocol {
    var registerError: Error?
    var onChallenge: (() -> Void)?

    private(set) var challengeCallCount = 0
    private(set) var registerCallCount = 0

    func reset() {
        challengeCallCount = 0
        registerCallCount = 0
    }

    func createChallengeWrapper() -> CompoundOperationWrapper<String> {
        challengeCallCount += 1
        let hook = onChallenge

        return CompoundOperationWrapper(targetOperation: ClosureOperation {
            hook?()
            return UUID().uuidString
        })
    }

    func createRegisterOperation(_ requestClosure: @escaping () throws -> BackendAttestationRegisterRequest) -> BaseOperation<Void> {
        let error = registerError

        return ClosureOperation { [weak self] in
            _ = try requestClosure()
            self?.registerCallCount += 1

            if let error {
                throw error
            }
        }
    }
}

final class TestClock {
    private(set) var now = Date(timeIntervalSince1970: 1_700_000_000)

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}

final class SilentLogger: SDKLoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
}
