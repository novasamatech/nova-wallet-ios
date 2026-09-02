import Foundation
import DeviceCheck
import Operation_iOS

protocol AppAttestServiceProtocol {
    var isSupported: Bool { get }

    /// `clientData` receives the key id — generated here when `keyId` is nil — because the
    /// gateway's attestation client data is sha256(challenge ‖ clientId ‖ keyId).
    func createAttestationWrapper(
        using keyId: AppAttestKeyId?,
        clientData: @escaping (AppAttestKeyId) throws -> Data
    ) -> CompoundOperationWrapper<AppAttestAttestation>

    func createAssertionWrapper(
        keyId: AppAttestKeyId,
        clientData: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<AppAttestAssertion>
}

enum AppAttestServiceError: Error {
    case keyIdGeneration(Error?)
    case invalidKeyId
    case serviceUnavailable
    case attestationGeneric(Error?)
    case assertionGeneric(Error?)

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
    let service: DeviceCheckAttesting

    init(service: DeviceCheckAttesting = DCAppAttestService.shared) {
        self.service = service
    }

    private func createKeyIdOperation(
        using keyId: AppAttestKeyId?,
        service: DeviceCheckAttesting
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
        service: DeviceCheckAttesting,
        clientData: @escaping (AppAttestKeyId) throws -> Data
    ) -> BaseOperation<AppAttestAttestation> {
        AsyncClosureOperation { completion in
            let keyId = try keyIdOperation.extractNoCancellableResultData()
            let clientDataHash = try clientData(keyId).sha256()

            service.attestKey(keyId, clientDataHash: clientDataHash) { attestation, error in
                if let attestation {
                    completion(.success(AppAttestAttestation(keyId: keyId, attestation: attestation)))
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
        using keyId: AppAttestKeyId?,
        clientData: @escaping (AppAttestKeyId) throws -> Data
    ) -> CompoundOperationWrapper<AppAttestAttestation> {
        let keyIdOperation = createKeyIdOperation(using: keyId, service: service)
        let attestationOperation = createAttestOperation(
            dependingOn: keyIdOperation,
            service: service,
            clientData: clientData
        )

        attestationOperation.addDependency(keyIdOperation)

        return CompoundOperationWrapper(
            targetOperation: attestationOperation,
            dependencies: [keyIdOperation]
        )
    }

    func createAssertionWrapper(
        keyId: AppAttestKeyId,
        clientData: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<AppAttestAssertion> {
        let operation = AsyncClosureOperation<AppAttestAssertion> { completionClosure in
            let clientDataHash = try clientData().sha256()

            self.service.generateAssertion(keyId, clientDataHash: clientDataHash) { assertion, error in
                if let assertion {
                    completionClosure(.success(assertion))
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
