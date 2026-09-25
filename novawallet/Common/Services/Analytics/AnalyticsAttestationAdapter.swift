import Foundation
import Operation_iOS
import NovaAnalytics
import NovaAppAttest

final class AnalyticsAttestationAdapter {
    private let holder: BackendAttestationHolderProtocol

    init(holder: BackendAttestationHolderProtocol) {
        self.holder = holder
    }
}

extension AnalyticsAttestationAdapter: AnalyticsAttestationProviding {
    func createAttestationWrapper() -> CompoundOperationWrapper<AnalyticsAttestation> {
        let endpointWrapper = holder.createEndpointWrapper()

        let mapOperation = ClosureOperation<AnalyticsAttestation> {
            let endpoint = try endpointWrapper.targetOperation.extractNoCancellableResultData()

            return AnalyticsAttestation(gatewayURL: endpoint.gatewayURL, provider: endpoint.provider)
        }

        mapOperation.addDependency(endpointWrapper.targetOperation)

        return endpointWrapper.insertingTail(operation: mapOperation)
    }

    func createExclusiveWrapper<T>(
        _ exchangeClosure: @escaping () throws -> CompoundOperationWrapper<T>
    ) -> CompoundOperationWrapper<T> {
        holder.exchangeGate.createExclusiveWrapper(exchangeClosure)
    }
}
