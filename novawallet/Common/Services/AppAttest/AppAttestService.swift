import Foundation
import DeviceCheck
import Operation_iOS
import CryptoKit
import Keystore_iOS

protocol AppAttestServiceProtocol {
    var isSupported: Bool { get }

    func createAttestationWrapper(
        for challengeClosure: @escaping () throws -> Data,
        using keyId: AppAttestKeyId?
    ) -> CompoundOperationWrapper<AppAttestModel>

    func createAssertionWrapper(
        challengeClosure: @escaping () throws -> Data,
        dataClosure: @escaping () throws -> Data?,
        keyId: AppAttestKeyId
    ) -> CompoundOperationWrapper<AppAttestAssertionModel>
}

enum AppAttestServiceError: Error {
    case keyIdGeneration(Error?)
    case invalidKeyId
    case serviceUnavailable
    case attestationGeneric(Error?)
    case assertionGeneric(Error?)
    case bundleIdUnavailable

    static func createDCSpecificError(
        from error: Error?,
        orUse appAttestError: AppAttestServiceError
    ) -> AppAttestServiceError {
        guard let dcError = error as? DCError else {
            return appAttestError
        }

        switch dcError.code {
        case .serverUnavailable:
            return .serviceUnavailable
        case .featureUnsupported,
             .unknownSystemFailure:
            return appAttestError
        case .invalidInput,
             .invalidKey:
            return .invalidKeyId
        @unknown default:
            return appAttestError
        }
    }
}

final class AppAttestService {
    let service: DCAppAttestService
    let hashCalculator: AppAttestClientHashing
    let bundle: Bundle

    init(
        service: DCAppAttestService = DCAppAttestService.shared,
        hashCalculator: AppAttestClientHashing = AppAttestClientHashCalculator(),
        bundle: Bundle = .main
    ) {
        self.service = service
        self.hashCalculator = hashCalculator
        self.bundle = bundle
    }

    private func createKeyIdOperation(
        using keyId: AppAttestKeyId?,
        service: DCAppAttestService
    ) -> BaseOperation<AppAttestKeyId> {
        if let keyId {
            return .createWithResult(keyId)
        }

        return AsyncClosureOperation<AppAttestKeyId>(operationClosure: { completion in
            service.generateKey { newKeyId, error in
                if let newKeyId {
                    completion(.success(newKeyId))
                } else {
                    completion(.failure(AppAttestServiceError.keyIdGeneration(error)))
                }
            }
        })
    }

    private func createAttestOperation(
        dependingOn keyIdOperation: BaseOperation<AppAttestKeyId>,
        service: DCAppAttestService,
        hashCalculator: AppAttestClientHashing,
        challengeClosure: @escaping () throws -> Data
    ) -> BaseOperation<AppAttestModel> {
        AsyncClosureOperation { completion in
            let keyId = try keyIdOperation.extractNoCancellableResultData()
            let challenge = try challengeClosure()
            let hash = try hashCalculator.hash(challenge: challenge, data: nil)

            service.attestKey(keyId, clientDataHash: hash) { attestation, error in
                if let attestation {
                    completion(.success(.init(keyId: keyId, challenge: challenge, result: attestation)))
                } else {
                    let attestationError = AppAttestServiceError.createDCSpecificError(
                        from: error,
                        orUse: .attestationGeneric(error)
                    )

                    completion(.failure(attestationError))
                }
            }
        }
    }
}

extension AppAttestService: AppAttestServiceProtocol {
    var isSupported: Bool { service.isSupported }

    func createAttestationWrapper(
        for challengeClosure: @escaping () throws -> Data,
        using keyId: AppAttestKeyId?
    ) -> CompoundOperationWrapper<AppAttestModel> {
        let keyIdOperation = createKeyIdOperation(using: keyId, service: service)
        let attestationOperation = createAttestOperation(
            dependingOn: keyIdOperation,
            service: service,
            hashCalculator: hashCalculator,
            challengeClosure: challengeClosure
        )

        attestationOperation.addDependency(keyIdOperation)

        return CompoundOperationWrapper(targetOperation: attestationOperation, dependencies: [keyIdOperation])
    }

    func createAssertionWrapper(
        challengeClosure: @escaping () throws -> Data,
        dataClosure: @escaping () throws -> Data?,
        keyId: AppAttestKeyId
    ) -> CompoundOperationWrapper<AppAttestAssertionModel> {
        let operation = AsyncClosureOperation { completionClosure in
            let challenge = try challengeClosure()
            let data = try dataClosure()

            let hash = try self.hashCalculator.hash(challenge: challenge, data: data)

            guard let bundleId = self.bundle.bundleIdentifier else {
                throw AppAttestServiceError.bundleIdUnavailable
            }

            self.service.generateAssertion(keyId, clientDataHash: hash) { assertion, error in
                if let assertion {
                    let model = AppAttestAssertionModel(
                        keyId: keyId,
                        challenge: challenge,
                        assertion: assertion,
                        bodyData: data,
                        bundleId: bundleId
                    )

                    completionClosure(.success(model))
                } else {
                    let assertionError = AppAttestServiceError.createDCSpecificError(
                        from: error,
                        orUse: .assertionGeneric(error)
                    )

                    completionClosure(.failure(assertionError))
                }
            }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
