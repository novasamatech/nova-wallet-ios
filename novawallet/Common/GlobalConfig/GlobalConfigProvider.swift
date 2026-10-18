import Foundation
import Operation_iOS

protocol GlobalConfigProviding {
    /// Answers from a process-lifetime cache once any fetch has succeeded, so a value that
    /// changes remotely mid-process is only seen on the next launch.
    func createConfigWrapper() -> CompoundOperationWrapper<GlobalConfig>

    /// Always refetches and refreshes the cache. Required by anything that must observe a
    /// remote change within the life of the process, such as the analytics kill switch.
    func createFreshConfigWrapper() -> CompoundOperationWrapper<GlobalConfig>
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

        return createFreshConfigWrapper()
    }

    func createFreshConfigWrapper() -> CompoundOperationWrapper<GlobalConfig> {
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
