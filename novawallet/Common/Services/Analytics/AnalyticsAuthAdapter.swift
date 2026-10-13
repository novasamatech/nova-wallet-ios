import Foundation
import Operation_iOS
import NovaAnalytics

final class AnalyticsAuthAdapter: AnalyticsAuthProvidingProtocol {
    private let provider: NovaAuthProvidingProtocol

    init(provider: NovaAuthProvidingProtocol) { self.provider = provider }

    var authAvailability: AnalyticsAuthAvailability { map(provider.endpointAvailability) }

    func addAvailabilityObserver(
        _ owner: AnyObject,
        closure: @escaping (AnalyticsAuthAvailability) -> Void
    ) -> AnalyticsAuthAvailability {
        let current = provider.addAvailabilityObserver(owner) { [weak self] in
            guard let self else { return }
            closure(self.map($0))
        }
        return map(current)
    }

    private func map(_ availability: NovaAuthEndpointAvailability) -> AnalyticsAuthAvailability {
        AnalyticsAuthAvailability(
            revision: availability.revision,
            invalidationRevision: availability.invalidationRevision,
            auth: availability.endpoint.map { AnalyticsAuth(context: $0.context, client: $0.client) }
        )
    }

    func addContextObserver(_ owner: AnyObject, closure: @escaping () -> Void) {
        provider.addContextObserver(owner, closure: closure)
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
