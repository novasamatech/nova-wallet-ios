import Foundation
import RobinHood

struct StakingGlobalConfig: Decodable {
    let multiStakingApiUrl: URL
}

protocol StakingGlobalConfigProviding {
    func createConfigWrapper() -> CompoundOperationWrapper<StakingGlobalConfig>
}

final class StakingGlobalConfigProvider: BaseFetchOperationFactory {
    let configUrl: URL

    @Atomic(defaultValue: nil)
    private var config: StakingGlobalConfig?

    init(configUrl: URL) {
        self.configUrl = configUrl
    }
}

extension StakingGlobalConfigProvider: StakingGlobalConfigProviding {
    func createConfigWrapper() -> CompoundOperationWrapper<StakingGlobalConfig> {
        if let config {
            return CompoundOperationWrapper.createWithResult(config)
        }

        let fetchOperation: BaseOperation<StakingGlobalConfig> = createFetchOperation(
            from: configUrl,
            shouldUseCache: false
        )

        let mapOperation = ClosureOperation<StakingGlobalConfig> {
            let config = try fetchOperation.extractNoCancellableResultData()
            self.config = config
            return config
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
    }
}
