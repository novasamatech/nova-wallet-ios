import Foundation
import Operation_iOS

protocol GlobalConfigProviding {
    func createConfigWrapper() -> CompoundOperationWrapper<GlobalConfig>
}

final class GlobalConfigProvider: BaseFetchOperationFactory {
    let configUrl: URL

    @Atomic(defaultValue: nil)
    private var config: GlobalConfig?

    init(configUrl: URL) {
        self.configUrl = configUrl
    }
}

extension GlobalConfigProvider: GlobalConfigProviding {
    func createConfigWrapper() -> CompoundOperationWrapper<GlobalConfig> {
        if let config {
            return CompoundOperationWrapper.createWithResult(config)
        }

        let fetchOperation: BaseOperation<GlobalConfig> = createFetchOperation(
            from: configUrl,
            shouldUseCache: false
        )

        let mapOperation = ClosureOperation<GlobalConfig> {
            let config = try fetchOperation.extractNoCancellableResultData()
            self.config = config
            return config
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
    }
}
