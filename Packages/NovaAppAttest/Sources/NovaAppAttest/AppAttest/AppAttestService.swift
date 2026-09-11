import Foundation
import DeviceCheck
import Operation_iOS

public protocol AppAttestServiceProtocol {
    var isSupported: Bool { get }

    /// Split from attestation so the caller can persist the identifier before attesting it:
    /// Apple offers no way to recover a key identifier once it is lost.
    func createKeyGenerationOperation() -> BaseOperation<AppAttestKeyId>

    func createAttestationWrapper(
        using keyId: AppAttestKeyId,
        clientData: @escaping (AppAttestKeyId) throws -> Data
    ) -> CompoundOperationWrapper<AppAttestAttestation>

    func createAssertionWrapper(
        keyId: AppAttestKeyId,
        clientData: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<AppAttestAssertion>
}

public enum AppAttestServiceError: Error {
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

public final class AppAttestService {
    let service: DeviceCheckAttesting

    public init(service: DeviceCheckAttesting = DCAppAttestService.shared) {
        self.service = service
    }
}

extension AppAttestService: AppAttestServiceProtocol {
    public var isSupported: Bool { service.isSupported }

    public func createKeyGenerationOperation() -> BaseOperation<AppAttestKeyId> {
        let service = service

        return AsyncClosureOperation<AppAttestKeyId> { completion in
            service.generateKey { newKeyId, error in
                if let newKeyId {
                    completion(.success(newKeyId))
                } else {
                    completion(.failure(AppAttestServiceError.keyIdGeneration(error)))
                }
            }
        }
    }

    public func createAttestationWrapper(
        using keyId: AppAttestKeyId,
        clientData: @escaping (AppAttestKeyId) throws -> Data
    ) -> CompoundOperationWrapper<AppAttestAttestation> {
        let service = service

        let operation = AsyncClosureOperation<AppAttestAttestation> { completion in
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

        return CompoundOperationWrapper(targetOperation: operation)
    }

    public func createAssertionWrapper(
        keyId: AppAttestKeyId,
        clientData: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<AppAttestAssertion> {
        let service = service

        let operation = AsyncClosureOperation<AppAttestAssertion> { completionClosure in
            let clientDataHash = try clientData().sha256()

            service.generateAssertion(keyId, clientDataHash: clientDataHash) { assertion, error in
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
