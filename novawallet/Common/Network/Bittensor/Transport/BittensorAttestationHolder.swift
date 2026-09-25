import Foundation
import NovaAppAttest
import Operation_iOS

protocol BittensorAttestationHolderProtocol: AnyObject {
    func createEndpointWrapper() -> CompoundOperationWrapper<BackendAttestationEndpoint>
}

final class BittensorAttestationHolder {
    private let attestationHolder: BackendAttestationHolderProtocol
    private let appAttest: AppAttestServiceProtocol
    private let appIdentity: AppAttestAppIdentity?
    private let isUnitTesting: Bool

    init(
        attestationHolder: BackendAttestationHolderProtocol,
        appAttest: AppAttestServiceProtocol,
        appIdentity: AppAttestAppIdentity?,
        isUnitTesting: Bool
    ) {
        self.attestationHolder = attestationHolder
        self.appAttest = appAttest
        self.appIdentity = appIdentity
        self.isUnitTesting = isUnitTesting
    }
}

extension BittensorAttestationHolder: BittensorAttestationHolderProtocol {
    func createEndpointWrapper() -> CompoundOperationWrapper<BackendAttestationEndpoint> {
        guard !isUnitTesting, appIdentity != nil else {
            return .createWithError(BittensorApiError.unsupportedDevice)
        }

        let mode = BackendAttestationModeResolver.resolve(isAppAttestSupported: appAttest.isSupported)

        guard mode == .appAttest else {
            return .createWithError(BittensorApiError.unsupportedDevice)
        }

        let endpointWrapper = attestationHolder.createEndpointWrapper()

        let checkedOperation = ClosureOperation<BackendAttestationEndpoint> {
            do {
                return try endpointWrapper.targetOperation.extractNoCancellableResultData()
            } catch {
                throw BittensorApiError.transport(error)
            }
        }

        checkedOperation.addDependency(endpointWrapper.targetOperation)

        return endpointWrapper.insertingTail(operation: checkedOperation)
    }
}
