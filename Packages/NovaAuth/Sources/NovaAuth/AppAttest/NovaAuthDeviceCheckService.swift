import Foundation
import DeviceCheck
import Operation_iOS
import NovaOperationSupport

protocol NovaAuthDeviceCheckProtocol: AnyObject {
    var isSupported: Bool { get }
    func generateKey(completionHandler: @escaping (String?, Error?) -> Void)
    func attestKey(_ keyId: String, clientDataHash: Data, completionHandler: @escaping (Data?, Error?) -> Void)
    func generateAssertion(_ keyId: String, clientDataHash: Data, completionHandler: @escaping (Data?, Error?) -> Void)
}

extension DCAppAttestService: NovaAuthDeviceCheckProtocol {}

final class NovaAuthDeviceCheckService: NovaAuthAppAttestProtocol {
    private let service: NovaAuthDeviceCheckProtocol
    private let timeout: TimeInterval
    private let proofCalls = NovaAuthProofCalls()
    var isSupported: Bool { service.isSupported }

    init(service: NovaAuthDeviceCheckProtocol = DCAppAttestService.shared, timeout: TimeInterval = 100) {
        self.service = service
        self.timeout = timeout
    }

    func isBusy(keyID: String) -> Bool {
        proofCalls.isBusy(keyID: keyID)
    }

    func createKeyWrapper() -> CompoundOperationWrapper<String> {
        let service = service
        return createWrapper { completion in
            service.generateKey { key, error in
                completion(Self.result(value: key, error: error) { try NovaAuthValidation.keyID($0) })
            }
        }
    }

    func createAttestationWrapper(
        keyID: String,
        clientDataHash: Data,
        beforeAttest: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<Data> {
        createProofWrapper(keyID: keyID, clientDataHash: clientDataHash, attestation: true, beforeAttest: beforeAttest)
    }

    func createAssertionWrapper(keyID: String, clientDataHash: Data) -> CompoundOperationWrapper<Data> {
        createProofWrapper(keyID: keyID, clientDataHash: clientDataHash, attestation: false)
    }
}

private extension NovaAuthDeviceCheckService {
    func createProofWrapper(
        keyID: String,
        clientDataHash: Data,
        attestation: Bool,
        beforeAttest: @escaping () throws -> Void = {}
    ) -> CompoundOperationWrapper<Data> {
        do {
            try NovaAuthValidation.keyID(keyID)
            guard clientDataHash.count == 32 else { throw NovaAuthError.invalidRequest }
        } catch { return .createWithError(error) }
        let service = service
        let proofCalls = proofCalls
        return createWrapper { completion in
            guard let lease = proofCalls.acquire(keyID: keyID) else {
                completion(.failure(NovaAuthAppAttestError.serverUnavailable))
                return
            }
            let callback: (Data?, Error?) -> Void = { data, error in
                guard proofCalls.release(keyID: keyID, lease: lease) else { return }
                completion(Self.result(value: data, error: error) {
                    guard !$0.isEmpty,
                          $0.count <= (attestation ? 49152 : 6144) else { throw NovaAuthError.invalidResponse }
                })
            }
            // The framing layer already produced SHA256(P3). Apple receives these exact bytes.
            if attestation {
                do {
                    try beforeAttest()
                } catch {
                    _ = proofCalls.release(keyID: keyID, lease: lease)
                    completion(.failure(error))
                    return
                }
                service.attestKey(keyID, clientDataHash: clientDataHash, completionHandler: callback)
            } else {
                service.generateAssertion(keyID, clientDataHash: clientDataHash, completionHandler: callback)
            }
        }
    }

    func createWrapper<T>(_ call: @escaping (@escaping (Result<T, Error>) -> Void) -> Void)
        -> CompoundOperationWrapper<T> {
        guard isSupported else { return .createWithError(NovaAuthAppAttestError.unsupported) }
        guard timeout.isFinite, timeout > 0,
              timeout <= 100 else { return .createWithError(NovaAuthError.invalidConfiguration) }
        let pending = NovaAuthPlatformCall<T>()
        let timeout = timeout
        let operation = AsyncClosureOperation<T>(operationClosure: { completion in
            pending.begin(timeout: timeout, completion: completion, call: call)
        }, cancelationClosure: { pending.finish(.failure(NovaAuthError.cancelled)) })
        return CompoundOperationWrapper(targetOperation: operation)
    }

    static func result<T>(value: T?, error: Error?, validate: (T) throws -> Void) -> Result<T, Error> {
        if let error = error as? DCError {
            switch error.code {
            case .serverUnavailable: return .failure(NovaAuthAppAttestError.serverUnavailable)
            case .invalidKey, .invalidInput: return .failure(NovaAuthAppAttestError.invalidKey)
            case .featureUnsupported: return .failure(NovaAuthAppAttestError.unsupported)
            default: return .failure(NovaAuthAppAttestError.failure)
            }
        }
        guard error == nil, let value else { return .failure(NovaAuthAppAttestError.failure) }
        do {
            try validate(value)
            return .success(value)
        } catch { return .failure(NovaAuthAppAttestError.failure) }
    }
}

private final class NovaAuthProofCalls {
    private let mutex = NSLock()
    private var leases: [String: UUID] = [:]

    func isBusy(keyID: String) -> Bool {
        mutex.novaAuthLocked { leases[keyID] != nil }
    }

    func acquire(keyID: String) -> UUID? {
        mutex.novaAuthLocked {
            guard leases[keyID] == nil else { return nil }
            let lease = UUID()
            leases[keyID] = lease
            return lease
        }
    }

    // After native invocation, only the SDK callback can release the key, never a local timeout.
    func release(keyID: String, lease: UUID) -> Bool {
        mutex.novaAuthLocked {
            guard leases[keyID] == lease else { return false }
            leases.removeValue(forKey: keyID)
            return true
        }
    }
}

private final class NovaAuthPlatformCall<Value> {
    private let mutex = NSLock()
    private var completion: ((Result<Value, Error>) -> Void)?
    private var finished = false
    private var timer: DispatchWorkItem?

    func begin(
        timeout: TimeInterval,
        completion: @escaping (Result<Value, Error>) -> Void,
        call: (@escaping (Result<Value, Error>) -> Void) -> Void
    ) {
        mutex.lock()
        guard !finished else { mutex.unlock(); completion(.failure(NovaAuthError.cancelled)); return }
        self.completion = completion
        let timer = DispatchWorkItem { [weak self] in self?.finish(.failure(NovaAuthAppAttestError.timedOut)) }
        self.timer = timer
        mutex.unlock()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: timer)
        call { [weak self] in self?.finish($0) }
    }

    func finish(_ result: Result<Value, Error>) {
        mutex.lock()
        guard !finished else { mutex.unlock(); return }
        finished = true
        let completion = completion
        self.completion = nil
        timer?.cancel()
        timer = nil
        mutex.unlock()
        completion?(result)
    }
}
