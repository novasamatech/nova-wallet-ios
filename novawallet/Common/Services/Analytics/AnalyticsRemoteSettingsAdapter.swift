import Foundation
import Operation_iOS
import NovaAnalytics

/// Bridges the app's `GlobalConfigProvider` to the package's `AnalyticsRemoteSettings`.
/// `GlobalConfig` and `AnalyticsRemoteConfig` are app models and must not cross the
/// boundary, so only the resolved flag is handed over.
final class AnalyticsRemoteSettingsAdapter {
    private let configProvider: GlobalConfigProviding

    init(configProvider: GlobalConfigProviding = GlobalConfigProvider.shared) {
        self.configProvider = configProvider
    }
}

extension AnalyticsRemoteSettingsAdapter: AnalyticsRemoteSettings {
    func createRemoteEnabledWrapper() -> CompoundOperationWrapper<Bool> {
        let configWrapper = configProvider.createConfigWrapper()

        // Fail-open on the value: a config with no analytics block means enabled. Fail-open
        // on the error is the facade's job — it leaves availability alone.
        let mapOperation = ClosureOperation<Bool> {
            let config = try configWrapper.targetOperation.extractNoCancellableResultData()

            return config.analytics?.enabled ?? true
        }

        mapOperation.addDependency(configWrapper.targetOperation)

        return configWrapper.insertingTail(operation: mapOperation)
    }
}
