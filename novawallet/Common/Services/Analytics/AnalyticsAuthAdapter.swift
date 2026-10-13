import Foundation
import NovaAnalytics
import Operation_iOS

final class AnalyticsAuthAdapter: AnalyticsAuthProvidingProtocol {
    private let provider: NovaAuthProvidingProtocol

    init(provider: NovaAuthProvidingProtocol) {
        self.provider = provider
    }

    func createAuthWrapper() -> CompoundOperationWrapper<AnalyticsAuth> {
        let endpoint = provider.createEndpointWrapper()
        let map = ClosureOperation<AnalyticsAuth> {
            let value = try endpoint.targetOperation.extractNoCancellableResultData()
            return AnalyticsAuth(context: value.context, client: value.client)
        }
        map.addDependency(endpoint.targetOperation)
        return endpoint.insertingTail(operation: map)
    }
}
