import Foundation
import Operation_iOS
import NovaAppAttest

final class DeviceCheckAttestingSpy: DeviceCheckAttesting {
    var isSupported: Bool = true

    var generateKeyResult: Result<String, Error> = .success(UUID().uuidString)
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

    func reset() {
        synchronised {
            recordedGenerateKeyCalls = 0
            recordedAssertionHashes = []
        }
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

final class BackendAttestationRemoteFactorySpy: BackendAttestationRemoteFactoryProtocol {
    var challenge: () throws -> String = { UUID().uuidString }
    var registerError: Error?

    private let mutex = NSLock()
    private var recordedChallengeCalls = 0

    var challengeCallCount: Int {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return recordedChallengeCalls
    }

    func createChallengeWrapper() -> CompoundOperationWrapper<String> {
        mutex.lock()
        recordedChallengeCalls += 1
        mutex.unlock()

        let challenge = challenge

        return CompoundOperationWrapper(targetOperation: ClosureOperation { try challenge() })
    }

    func createRegisterOperation(
        _ requestClosure: @escaping () throws -> BackendAttestationRegisterRequest
    ) -> BaseOperation<Void> {
        let error = registerError

        return ClosureOperation {
            _ = try requestClosure()

            if let error {
                throw error
            }
        }
    }
}
