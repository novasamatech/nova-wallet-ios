import Foundation
import Operation_iOS
import NovaAnalytics

final class AnalyticsInfraURLAdapter {
    private let configProvider: GlobalConfigProviding

    init(configProvider: GlobalConfigProviding = GlobalConfigProvider.shared) {
        self.configProvider = configProvider
    }
}

extension AnalyticsInfraURLAdapter: AnalyticsInfraURLProviding {
    func createInfraURLWrapper() -> CompoundOperationWrapper<URL> {
        let configWrapper = configProvider.createConfigWrapper()

        let mapOperation = ClosureOperation<URL> {
            try configWrapper.targetOperation.extractNoCancellableResultData().infraUrl
        }

        mapOperation.addDependency(configWrapper.targetOperation)

        return configWrapper.insertingTail(operation: mapOperation)
    }
}
