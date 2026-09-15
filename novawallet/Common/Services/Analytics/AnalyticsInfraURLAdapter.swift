import Foundation
import Operation_iOS
import NovaAnalytics

/// Bridges the app's `GlobalConfigProvider` to the package's `AnalyticsInfraURLProviding`.
/// `GlobalConfig` is an app model and must not cross the boundary, so only the URL is handed over.
final class AnalyticsInfraURLAdapter {
    private let configProvider: GlobalConfigProviding

    init(configProvider: GlobalConfigProviding = GlobalConfigProvider.shared) {
        self.configProvider = configProvider
    }
}

extension AnalyticsInfraURLAdapter: AnalyticsInfraURLProviding {
    func createInfraURLWrapper() -> CompoundOperationWrapper<URL> {
        // The cached wrapper: the gateway is resolved once per process and the attestation key
        // binds to it, so a host that changes remotely is picked up on the next launch.
        let configWrapper = configProvider.createConfigWrapper()

        let mapOperation = ClosureOperation<URL> {
            try configWrapper.targetOperation.extractNoCancellableResultData().infraUrl
        }

        mapOperation.addDependency(configWrapper.targetOperation)

        return configWrapper.insertingTail(operation: mapOperation)
    }
}
